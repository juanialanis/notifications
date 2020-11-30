require './models/subscription.rb'

class SubscriptionService
	
	def self.unsubscribe(category, user)
		if user && category && user.remove_category(category)
			return user.categories_dataset if user.categories_dataset.to_a.length.positive?
		else
			raise ArgumentError.new("An error has ocurred when trying unsubscribe you from #{category}")
			return user.categories_dataset
		end
	end	

	def self.subscribe(user, categoryA)
		category = Category.first(name: categoryA)
	    if user && category
	      category.add_user(user)
	      if !category.save
	        raise ArgumentError.new("You are already subscribed to #{category}!")
	      end
	    end
	end
end