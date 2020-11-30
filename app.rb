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



  def cant_pages(cantdocs)
    @docsperpage = 12
    @pagelimit = if (cantdocs % @docsperpage).zero?
                   cantdocs / @docsperpage
                 else
                   cantdocs / @docsperpage + 1
                 end
  end

  get '/aboutus' do
    erb :aboutus, layout: :layout
  end


  def send_code_email(useremail, user)
    @code = rand.to_s[2..6]
    @user = user.name

    Pony.mail({
                to: useremail,
                via: :smtp,
                via_options: {
                  address: 'smtp.gmail.com',
                  port: '587',
                  user_name: 'documentuploadsystem@gmail.com',
                  password: 'rstmezqnvkygptjl',
                  authentication: :plain,
                  domain: 'gmail.com'
                },
                subject: 'DUNS Verification code',
                headers: { 'Content-Type' => 'text/html' },
                body: erb(:retrieve, layout: false)
              })

    @code
  end


  

  

end
