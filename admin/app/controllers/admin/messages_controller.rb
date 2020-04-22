# encoding: utf-8
# frozen_string_literal: true

module Admin
  class MessagesController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def new
      authorize model
      return render json: {
        user_id: @found_user.id,
        staff_id: current_user.id,
        type: model_type,
        category: model.default_category(@found_user),
        reason: model.default_reason(@found_user),
        message: nil,
        reviewed: false,
        categories: model.categories.keys,
        reasons: model.reasons.keys,
        staff_name: current_user.print_first_name_only
      }
    end

    def index
      messages = authorize model.order(:created_at).where(user: @found_user)

      if Boolean.parse(params[:force]) || stale?(messages)
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y)

          deflator.stream false, :version, last_update
          deflator.stream true, :messages, '['

          i = 0
          messages.map do |m|
            deflator.stream (i += 1) > 1, nil, {
              id: m.id,
              user_id: m.user_id,
              staff_id: m.staff_id,
              staff_name: m.staff.user.print_first_name_only,
              type: model_type(m.class),
              category: m.category,
              reason: m.reason,
              message: m.message,
              reviewed: m.reviewed,
              created_at: m.created_at.strftime('%a %b %d @ %R'),
              categories: m.class.categories.keys,
              reasons: m.class.reasons.keys
            }
          end

          deflator.stream false, nil, ']'

          deflator.close
        end
      end
    end

    def create
      save_message @found_user.__send__ model_type.pluralize
    end

    def update
      message = @found_user.__send__(model_type.pluralize).find_by(id: params[:id])
      save_message authorize(message, message_unchanged?(message) ? :category? : :update?), 'update!'.to_sym
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def last_update
        begin
          return nil unless @found_user.__send__(model_type.pluralize).count > 0
          @found_user.__send__(model_type.pluralize).
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end

      def model
        case params[:type].to_s
        when /note/
          User::Note
        when /alert/
          User::Alert
        when /history/
          User::ContactHistory
        when /attempt/
          User::ContactAttempt
        else
          User::Message
        end
      end

      def model_type(m = model)
        m.to_s.split('::').last.underscore
      end

      def message_unchanged?(message)
        message.message.strip.downcase == whitelisted_message_params[:message].strip.downcase
      end

      def save_message(message, method = 'create!'.to_sym)
        successful, errors, rel = nil

        begin
          params[:message][:staff_id] = current_user.category_id unless message.respond_to?(:staff_id) && message.staff_id.present?
          if (method == :update!) && whitelisted_message_params[:message].blank?
            message.destroy!
          else
            message.__send__(method, whitelisted_message_params)
          end
          successful = true
        rescue
          successful = false
          puts errors = $!.message
          puts $!.backtrace
        end

        return successful ? render_success : not_authorized(errors, 422)
      end

      def whitelisted_message_params
        params.require(:message).permit(:id, :staff_id, :category, :reason, :message, :reviewed, :type)
      end
  end
end
