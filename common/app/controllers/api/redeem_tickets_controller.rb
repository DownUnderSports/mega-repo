# encoding: utf-8
# frozen_string_literal: true

module API
  class RedeemTicketsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    def show
      ticket = ThankYouTicket.find_by(uuid: params[:id])
      unless ticket || params[:dus_id].blank? || (params[:id].to_s.size != 36)
        if (u = User[params[:dus_id]]) && u.is_traveler?
          ticket = ThankYouTicket.create!(user: u, uuid: params[:id])
        end
      end
      return render json: { message: "Thank You Ticket not found" }, status: 422 unless ticket
      return render json: { message: "Thank You Ticket has already been redeemed", user: ticket.user&.print_names }, status: 422 if ticket.submitted?
      return render json: { ticket: ticket }
    rescue
      puts $!.message
      puts $!.backtrace
      render json: { message: "Provided Thank You Ticket ID is not valid" }, status: 422
    end

    def update
      ticket = ThankYouTicket.find_by(uuid: params[:id])
      return render json: { message: "Thank You Ticket not found" }, status: 422 unless ticket
      return render json: { message: "Thank You Ticket has already been redeemed", user: ticket.user&.print_names }, status: 422 if ticket.submitted?
      if ticket.update(whitelisted_ticket_params)
        return render json: { success: true }
      else
        return render json: { errors: ticket.errors.full_messages }, status: 422
      end
    rescue
      puts $!.message
      puts $!.backtrace
      render json: { message: $!.message }, status: 422
    end

    def whitelisted_ticket_params
      params.require(:ticket).permit(:name, :phone, :email, :mailing_address)
    end
  end
end
