# encoding: utf-8
# frozen_string_literal: true

module Lineup
  extend ActiveSupport::Concern

  included do
    before_action :echo_count
    before_action :states_and_record, only: [ :index, :edit ]
    before_action :find_record, only: [ :update, :destroy ]
    alias :super_update :update

    respond_to :html, :json

    def self.underscored
      self.name.underscore
    end

    def self.connection_count
      Rails.redis.get(underscored).to_i
    end

    def self.connection_count_dec
      Rails.redis.decr underscored
    end

    def self.connection_count_inc
      Rails.redis.incr underscored
    end

    def self.zero_connection_count
      Rails.redis.set(underscored, 0)
    end

    def index
    end

    def show
      set_session
      set_base
      set_record

      return redirect_to go_to_record_path, turbolinks: true if @record

      set_states

      return yield if block_given?

      render :index
    end

    def edit
      # return render :index unless session[:state_abbr]
      if Boolean.parse params[:in_use]
        puts "\n\n####### PAGE IN USE #########\n\n"
        puts "record count: #{(@base.size.is_a?(Hash) ? @base.size.size : @base.size)}"
        puts "connection count: #{(self.class.connection_count || 2)}"
        unless (@base.size.is_a?(Hash) ? @base.size.size : @base.size) < (self.class.connection_count || 2)
          return redirect_to go_to_taken_path
        else
          return redirect_to go_to_index_path, turbolinks: true
        end
      end
    end

    def taken
      session[go_to_index_path] ||= []
      session[go_to_index_path] << params[:id]
      p session[go_to_index_path]
      set_base
      if set_record
        @taken_path = go_to_taken_path
        @current_path = go_to_record_path
        respond_to do |format|
          format.html
          format.json do
            return render json: {path: @current_path, taken: @taken_path}
          end
        end
      else
        return redirect_to go_to_index_path, turbolinks: true
      end
    end

    def update
      session[go_to_index_path] = []
      super(@record, send(params_method))
    end

    def destroy
    end

    def after_update_path(*args)
      redirect_to go_to_show_path, turbolinks: true
    end

    private
      def echo_count
        p self.class.connection_count
      end

      def set_session
        session[:state_abbr] = params[:state_abbr] if params[:state_abbr]

        return render :index unless session[:state_abbr]
      end

      def set_base
        @base = model.__send__(list_method, session[:state_abbr].upcase).where.not(id: session[go_to_index_path]) if session[:state_abbr]
      end

      def set_record
        @record = @base.random_record if @base
      end

      def set_states
        @states = model.state_list
        map_states
      end

      def map_states
        @states = @states.map {|state| state.state_id} if !(@states.is_a?(Array))
      end

      def go_to_show_path
        send(show_path, session[:state_abbr])
      end

      def go_to_record_path
        send(record_path, @record)
      end

      def go_to_index_path
        send(index_path)
      end

      def go_to_taken_path
        send(taken_path, session[:state_abbr])
      end

      def find_record
        @record = model.find_by(id: params[:id]) if params[:id]
        session[:state_abbr] ||= @record.state.abbr if @record
        @record
      end

      def find_state
        @state = State.find_by_value((params[:state_abbr] || session[:state_abbr]).upcase) if params[:state_abbr] || session[:state_abbr]
      end

      def states_and_record
        find_record
        set_base
        find_state
        set_states
      end

      def model
        raise "model Not Defined"
      end

      def list_method
        raise "list_method Not Defined"
      end

      def params_method
        raise "params_method Not Defined!"
      end

      def record_path
        raise "record_path Not Defined!"
      end

      def show_path
        raise "show_path Not Defined!"
      end

      def index_path
        raise "index_path Not Defined!"
      end

      def taken_path
        show_path
      end
  end
end
