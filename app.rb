# frozen_string_literal: true

# Implements the website backend.
# Authors: Jeremias Parladorio & Juan Ignacio Alanis

require 'json'
require './models/init.rb'
require 'date'
require 'action_view'
require 'action_view/helpers'
require 'sinatra-websocket'
require './controllers/AccountController.rb'
require './controllers/BaseController.rb'
require './controllers/DocumentController.rb'
require './controllers/SubscriptionController.rb'
require './controllers/CategoryController.rb'
require './controllers/NotificationController.rb'

# Class that contains the implementation of the backend's logic.
class App < Sinatra::Base
  include ActionView::Helpers::DateHelper
  include FileUtils::Verbose

  use BaseController
  use AccountController
  use DocumentController
  use SubscriptionController
  use CategoryController
  use NotificationController

end
