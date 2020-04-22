# encoding: utf-8
# frozen_string_literal: true

namespace :gpg do
  desc 'Set up gpg key imports'
  task setup: :environment do
    puts 'INSTALLING GNUPG KEYS'

    ENV['GNUPGHOME'] = Rails.root.join('.gnupg').to_s

    creds = Rails.application.credentials
    should_reload_agent = false

    unless Dir.exist?(`echo #{ENV['GNUPGHOME']}`.strip)
      puts 'NEEDS DIR'
      should_reload_agent = true

      AESEncryptDir.decrypt(
        input_path: Rails.root.join('.gnupg.tar.b64.aes.gz.b64'),
        **creds.dig(:gpg, :directory)
      )
    end

    agent_file = "#{ENV['GNUPGHOME']}/gpg-agent.conf"
    if File.exist? agent_file
      if File.readlines(agent_file).grep(/allow-loopback-pinentry/).empty?
        should_reload_agent = true
        line_count = File.foreach(agent_file).inject(0) {|c, _l| c + 1 }
        File.open(agent_file, 'a') do |f|
          f.write "#{line_count.positive? ? "\n" : ''}allow-loopback-pinentry"
        end
      end
    else
      should_reload_agent = true
      File.open(agent_file, 'w') do |f|
        f.write 'allow-loopback-pinentry'
      end
    end

    if should_reload_agent
      puts 'RELOADING AGENT'
      `GNUPGHOME=#{ENV['GNUPGHOME']} gpg-connect-agent KILLAGENT /bye`
    end

    gpg_keys = `GNUPGHOME=#{ENV['GNUPGHOME']} gpg -K`

    unless gpg_keys =~ /#{creds.dig(:gpg, :fingerprint)}/
      %x{
        bash -c "GNUPGHOME=#{ENV['GNUPGHOME']} gpg \\
          --pinentry-mode loopback \\
          --passphrase #{creds.dig(:gpg, :passphrase)} \\
          --import #{ENV['GNUPGHOME']}/no-reply.secret.key"
      }

      %x{
        bash -c \
        "echo #{creds.dig(:gpg, :fingerprint)}:6: | gpg --import-ownertrust"
      }
    end

    unless gpg_keys =~ /#{creds.dig(:gpg, :signing, :fingerprint)}/
      %x{
        bash -c "GNUPGHOME=#{ENV['GNUPGHOME']} gpg \\
          --import #{ENV['GNUPGHOME']}/no-reply.signing.secret.key"
      }
      %x{
        bash -c "echo #{creds.dig(:gpg, :signing, :fingerprint)}:5: \\
          | GNUPGHOME=#{ENV['GNUPGHOME']} gpg --import-ownertrust"
      }
    end
  end

  desc 'Encrypt GPG dir with AES'
  task encrypt: :environment do
    puts gpg: {
      directory: AESEncryptDir.encrypt(Rails.root.join('.gnupg'), 'gpg_folder')
    }
  end
end
