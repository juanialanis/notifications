require 'sinatra/base'
require './controllers/BaseController'

class NotificationController < BaseController
	get '/notifications' do
	    getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
	    documents = Document.select(:id).where(id: getdocs, delete: false)

	    @notifications = Notification.where(user_id: @current_user.id, document_id: documents).order(:datetime).reverse
	    if params[:id] && Notification.first(document_id: params[:id], user_id: @current_user.id)
	      Notification.first(document_id: params[:id], user_id: @current_user.id).update(read: true)
	    end
	    erb :notifications
	end
end