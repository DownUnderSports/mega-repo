require 'openssl'
# require 'tempfile'

module AESEncryptDir
  def self.bin2hex(bin)
    return *bin.unpack('H*')
  end

  def self.hex2bin(bin)
    return [*bin].pack('H*')
  end

  def self.encrypt(input_path, auth_data, output_path = nil)
    file = File.open(input_path, 'r')

    cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
    cipher.key       = key       = cipher.random_key
    cipher.iv        = iv        = cipher.random_iv
    cipher.auth_data = auth_data ||= input_path.to_s

    Tempfile.open("#{input_path}.enc", encoding: 'ASCII-8BIT') do |encfile|
      Tempfile.open("#{input_path}.tar.b64", encoding: 'ASCII-8BIT') do |tarfile|
        tarfile << %x{ bash -c "tar -cz -C \\"#{File.dirname(input_path)}\\" \\"#{File.basename(input_path)}\\" | base64 --wrap 0" }
        tarfile.rewind

        encfile << cipher.update(tarfile.read)
        encfile << cipher.final
        encfile.rewind

        %x{ bash -c "cat #{encfile.path} | gzip -9nc | base64 --wrap 0 > \\"#{output_path || "#{input_path}.tar.b64.aes.gz.b64"}\\"" }
      end
      {
        key: bin2hex(key),
        iv: bin2hex(iv),
        tag: bin2hex(cipher.auth_tag),
        auth_data: auth_data
      }
    end
  rescue
    puts "failed: #{$!.message}"
    puts $!.backtrace
  end

  def self.decrypt(input_path:, key:, iv:, tag:, auth_data:, output_path: nil, rescued: false)
    output_path ||= "#{input_path.sub('.tar.b64.aes.gz.b64', '')}"

    Tempfile.open("#{input_path}.tar.b64", encoding: 'ASCII-8BIT') do |tarfile|
      Tempfile.open("#{input_path}.enc", encoding: 'ASCII-8BIT') do |encfile|
        cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
        cipher.key       = hex2bin(key)
        cipher.iv        = hex2bin(iv)
        cipher.auth_tag  = hex2bin(tag)
        cipher.auth_data = auth_data

        encfile << %x{ bash -c "cat \\"#{input_path}\\" | base64 -d | gunzip -c" }
        encfile.rewind

        tarfile << cipher.update(encfile.read)
        tarfile << cipher.final
        tarfile.rewind

        tmp_path = Rails.root.join('tmp', File.basename(output_path))
        %x{ rm -rf #{tmp_path} }
        %x{ bash -c "cat \\"#{tarfile.path}\\" | base64 -d | tar -C \\"#{File.dirname(tmp_path)}\\" -zx && mv \\"#{tmp_path}\\" \\"#{output_path}\\"" }
        %x{ rm -rf #{tmp_path} }
      end
    end
    # puts "[+] Encrypting: #{input_path}"
    # puts "[+] CipherMessage        (Key | IV | Ciphertext): #{bin2hex(key)} | #{bin2hex(iv)} | #{bin2hex(ciphertext)}"
  rescue
    unless rescued
      begin
        f_name = File.basename(input_path)
        path = Rails.root.join("tmp", f_name)
        s3_bucket.object("tmp/#{f_name}").download_file path
        if File.exist?(path)
          `mv #{path} #{input_path}`
          `rm -rf #{output_path}`
          return decrypt input_path: input_path, key: key, iv: iv, tag: tag, auth_data: auth_data, output_path: output_path, rescued: true
        end
      rescue
      end
    end
    puts "failed: #{$!.message}"
    puts $!.backtrace
  end
end
