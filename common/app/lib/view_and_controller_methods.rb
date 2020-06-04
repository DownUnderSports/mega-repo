# encoding: UTF-8
# frozen_string_literal: true

module ViewAndControllerMethods
  private
    def no_interest
      @no_interest ||= Interest.order(:id).where(contactable: false).limit(1).first.id
    end

    def interest_levels
      return @interest_levels if @interest_levels
      @interest_levels = {}
      Interest.all.each do |interest|
        @interest_levels[interest.id] = interest.level
      end
      @interest_levels
    end

    # def monday(date = Date.today)
    #   Date.commercial date.end_of_week.year, date.cweek
    # end
    #
    # def last_monday
    #   monday - 7
    # end

    def render_relative(relative_path, options={})
      render options.
        merge(
          partial:  caller[0].
                      split(".")[0].
                      split("/")[0...-1].
                      join("/").
                      gsub(/.*\/app\/views\//, "") \
                    + "/#{relative_path}"
        )
    end

    def add_domain(str)
      (str.to_s =~ /^http/) ? str.to_s : "#{route_info[:domain].to_s}/#{str.sub(/^\//, '')}"
    end

    def bootstrap_version
      '4.2.1'
    end

    def client_ip_address
      request.env["HTTP_X_FORWARDED_FOR"].try(:split, ',').try(:last).presence ||
      get_ip_address
    end

    def format_image_url(data)
      data[:image] = (route_info[:manifest][data[:image]] || data[:image]).gsub(/\./, '!') if data[:image].present?
    end

    def get_path_data(data = nil)
      original_path = data.presence || params[:path].presence || "root"
      path = original_path.split('/').first.to_sym

      data = (route_info[:links][path] || route_info[:links][:root] || {}).dup
      data = (route_info[:links][data[:to]] || route_info[:links][:root] || {}).dup if data[:alias]

      title = nil
      description = nil
      u = nil


      if !route_info[:links][path] && (u = User.find_by(dus_id: original_path))
        original_path = u.dus_id
      end

      if data[:resource]
        regex = Regexp.new(data[:path] + (data[:regex].presence || "/(.*?)(\\/|\\?|$)"))

        if u || (matches = regex.match(original_path))
          id = u ? u.dus_id : (data[:path].present? ? matches[1] : matches[0])

          if id
            data[:id] = id.upcase
            modeling = false
            if u
              resource = u
              modeling = true
            elsif data[:model] && models[data[:model]]
              resource = models[data[:model]].get(id)
              modeling = true
            elsif data[:api]
              resource = {}
              begin
                resulting = fetch(request.base_url + data[:api] + id)
                resource = JSON.parse(resulting).to_h.deep_stringify_keys
              rescue
                p "ERROR: #{$!.message}"
                puts $!.backtrace.first(10)
              end
            end
            id = (
              resource.present? &&
              (
                modeling ?
                resource.__send__(data[:method] || 'title') :
                resource[data[:method] || 'title']
              ).presence
            ) || 'Not Found'

            detail = (
              resource.present? &&
              (
                modeling ?
                resource.__send__(
                  data[:description_method] || data[:method] || 'title'
                ) :
                resource[data[:description_method] || data[:method] || 'title']
              ).presence
            ) || 'Not Found'

            title = data[:title].sub(/%RESOURCE%/, id)

            description = data[:direct_description] ? detail : data[:description].sub(/%RESOURCE%/, detail)


            if modeling && data[:direct_image]
              image_presence = data[:image_presence_method].presence ||
                data[:image_method].presence ||
                :image

              image_method = data[:image_method].presence || :image

              if (
                resource.respond_to?(image_presence) &&
                resource.respond_to?(image_method) &&
                resource.__send__(image_presence).present?
              )
                data[:image] = url_for(resource.__send__(image_method))
              else
                format_image_url(data)
              end
            end

          end
        else
          title = data[:index_title].presence || data[:title].sub(/%RESOURCE%/, 'Index')
          description = data[:index_description].presence || data[:description].sub(/%RESOURCE%/, 'Index')
        end
      end

      format_image_url(data) unless data[:direct_image]

      data[:full_url] = strip_tags("#{route_info[:domain].to_s}#{"#{data[:canonical].to_s}/#{encode_uri_component(data[:id])}/".gsub(/\/+/, '/')}")
      data[:title] = strip_tags(title.presence || data[:index_title] || data[:title] || "Down Under Sports")
      data[:description] = strip_tags(description.presence || data[:index_description] || data[:description])

      data
    end

    def gschema
      %Q(
        <link rel="canonical" href="#{path_data[:full_url]}">
        <meta itemprop="name" content="#{title}">
        <meta name="description" itemprop="description" content="#{path_data[:description].to_s}">
        #{path_data[:image].present? ? %Q(<meta itemprop="image" content="#{add_domain(path_data[:image])}">) : ''}
      ).html_safe
    end

    def ie_str
      (browser.ie? && !browser.edge?) ? 'is-ie' : ''
    end

    def meta_data
      {
        title: title,
        gschema: gschema,
        ograph: ograph,
        twitter: twitter,
      }
    end

    def mime_types
      route_info[:mime_types] ||= {
        css: 'text/css; charset=UTF-8',
        js: 'application/javascript; charset=UTF-8',
        json: 'application/json; charset=UTF-8',
        svg: 'image/svg+xml; charset=UTF-8',
      }
    end

    def models
      route_info[:models] ||= {
        user: User
      }.with_indifferent_access
    end

    def oembed_discovery
      %Q(
        <link rel="alternate" type="application/json+oembed" href="#{route_info[:domain].to_s}/oembed.json?url=#{encode_uri_component(request.original_url)}" title="#{title}" />
        <link rel="alternate" type="text/xml+oembed" href="#{route_info[:domain].to_s}/oembed.xml?url=#{encode_uri_component(request.original_url)}" title="#{title}" />
      ).html_safe
    end

    def ograph
      img_url = nil
      %Q(
        <meta property="fb:app_id" content="#{Rails.application.credentials.dig(:facebook, :app_id)}">
        <meta property="og:url" content="#{path_data[:full_url]}">
        <meta property="og:type" content="website">
        <meta property="og:title" content="#{title}">
        #{path_data[:image].present? ? %Q(
          <meta property="og:image" content="#{img_url = add_domain(path_data[:image])}">
          <meta property="og:image:#{(img_url =~ /^https/) ? 'secure_' : ''}url" content="#{img_url}">
          <meta property="og:image:alt" content="#{title}">
        ) : ''}
        <meta property="og:description" content="#{path_data[:description].to_s}">
        <meta property="og:site_name" content="Down Under Sports">
        <meta property="og:locale" content="en_US">
      ).html_safe
    end

    def path_data(data = nil)
      @path_data ||= get_path_data(data)
    end

    def route_info
      Rails.application.config.route_info
    end

    def title
      path_data[:title]
    end

    def twitter
      %Q(
        <meta name="twitter:card" content="summary">
        <meta name="twitter:url" content="#{path_data[:full_url]}">
        <meta name="twitter:title" content="#{title}">
        <meta name="twitter:description" content="#{path_data[:description].to_s}">
        #{path_data[:image].present? ? %Q(<meta name="twitter:image" content="#{add_domain(path_data[:image])}">) : ''}
      ).html_safe
    end

    def authenticated_user
      BetterRecord::Current.user
    end

    def pretty_date(date)
      raw(date.strftime("%A, %B %e<sup>#{date.day.ordinalize.sub(/\d+/, '')}</sup>, %Y"))
    end

    def pretty_short_date(date)
      raw(date.strftime("%B %e<sup>#{date.day.ordinalize.sub(/\d+/, '')}</sup>"))
    end

    def pretty_date_text(date)
      date.strftime("%A, %B #{date.day.ordinalize}, %Y")
    end

    def pretty_short_date_text(date)
      date.strftime("%B #{date.day.ordinalize}")
    end

    def generate_schedule_link(dus_id = nil)
      'mailto:mail@downundersports.com' \
        '?subject=Schedule%20an%20Appointment' \
        '&body=I%20would%20like%20to%20request%20a%20scheduled%20appointment%0D%0A%0D%0A' \
        'My Name:%20%0D%0A' \
        "#{dus_id.presence ? "Athlete%20DUS%20ID:%20#{dus_id}%0D%0A" : 'Athlete Name:%20%0D%0A' }" \
        'Date:%20%0D%0A' \
        'Time%20(with%20timezone):%20' \
        '%0D%0A%0D%0AI%20am%20curious%20about:%20'
    end

    def encode_uri_component(string)
      URI.escape(string.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def encode64(str)
      require "base64"
      Base64.strict_encode64 str
    end

    def get_hours_settings(skip_hours = false)
      hours_type = "hours"
      case skip_hours
      when Symbol
        hours_type = "#{skip_hours}_hours"
        skip_hours = nil
      else
        skip_hours = !!skip_hours
      end
      [ hours_type, skip_hours ]
    end
end
