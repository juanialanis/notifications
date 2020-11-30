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
		user = @current_user
		begin
			@categories = SubscriptionService.unsubscribe(category,user)
			@success = "You have been unsubscribed from #{category.name}"
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
    
    	user = @current_user
    	category = params['categories']
    	
    	begin
    		SubscriptionService.subscribe(user,category)
    		@success = "You are now subscribed to #{category}!"
    	rescue ArgumentError => e
    		@error = e.message
    	end
        if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length.positive?
          @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
          @categories = Category.where(id: @categories)
        end
        erb :suscat, layout: :layout
  	end

end