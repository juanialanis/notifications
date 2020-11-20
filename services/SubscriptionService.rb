require './models/subscription.rb'

class SubscriptionService
	
	def self.unsubscribe(category)
		if @current_user && category && @current_user.remove_category(category)
			#@success = "You have been unsubscribed from #{params[:category]}
			@categories = @current_user.categories_dataset if @current_user.categories_dataset.to_a.length.positive?
		else
			raise ArgumentError.new("An error has ocurred when trying unsubscribe you from #{category}")
			categories = @current_user.categories_dataset
		end
	end	


end