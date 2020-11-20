require 'sinatra/base'
require './controllers/BaseController'

class CategoryController < BaseController
	get '/mycategories' do
	    @categories = @current_user.categories_dataset if @current_user.categories_dataset.to_a.length.positive?
	    erb :yourcats, layout: :layout
	end
end