class FileValidation
  def self.student_list_fields
    @@student_list_fields ||= [
      "FIRST NAME",
      "LAST NAME",
      "CARE OF",
      "STREET",
      "CITY",
      "ST",
      "ZIP",
      "RESTRICTED NAME ENDORSEMENT LINE-IF APPLICABLE",
      "GENDER M=MALE F=FEMALE",
      "CLASS YEAR",
      "YOUR CONTACT ID"
    ]
  end

  def self.fundraising_packet_fields
    @@fundraising_packet_fields ||= FundraisingPacket::Processor.headers
  end

  def self.import_fields
    @@import_fields ||= Import::Processor.headers
  end

  def self.invite_date_fields
    @@invite_date_fields ||= Invite::Processor.display_headers
  end

  def self.school_fields
    @@school_fields ||= [
      {'col' => 'pid', 'link' => 'https://nces.ed.gov/globallocator/index.asp?search=1'},
      *%w{
        street
        city
        state
        zip
        name
      }
    ]
  end

  def self.rooming_fields
    @@rooming_fields ||= %w(
      dus_id
      room_number
    )
  end

  def self.to_csv(method)
    require 'csv'
    headers = send(method).map {|header| header['col'] || header}
    CSV.generate(headers: true) do |csv|
      csv << headers
    end
  end
end
