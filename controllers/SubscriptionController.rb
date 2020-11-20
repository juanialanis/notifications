require 'sinatra/base'
require './services/SubscriptionService'
require './controllers/BaseController'

class SubscriptionController < BaseController
	get '/unsubscribe' do
	    @categories = @current_user.categories_dataset if @current_user.categories_dataset.to_a.length.positive?
	    erb :deletecats, layout: :layout
	  end

	  post '/unsubscribe' do
		category = Category.first(name: params['category'])
		begin
			SubscriptionService.unsubscribe(category)
			@success = "You have been unsubscribed from #{category}"
			erb :deletecats, layout: :layout
			rescue ArgumentError => e
			@error = e.message
			erb :deletecats, layout: :layout
		end
	  end

	get '/subscribe' do
	    if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
	               .to_a.length.positive?
	      @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
	      @categories = Category.where(id: @categories)
	    end
	    erb :suscat, layout: :layout
	end

	post '/subscribe' do
    category = Category.first(name: params['categories'])
    if @current_user && category
      category.add_user(@current_user)
      if category.save
        @success = "You are now subscribed to #{params[:categories]}!"
        if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length.positive?
          @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
          @categories = Category.where(id: @categories)
        end
        erb :suscat, layout: :layout
      else
        @error = "You are already subscribed to #{params[:categories]}!"
        if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length.positive?
          @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
          @categories = Category.where(id: @categories)
        end
        erb :suscat, layout: :layout
      end
    end
  end

end