require './models/document.rb'
require 'sinatra-websocket'

class DocumentService
    include FileUtils::Verbose
	
	def self.view(document, session, read, id, settings)
		if document
	      doc = document.document
	      if read == 'true' && session
	        Notification.first(document_id: id, user_id: session[:user_id]).update(read: true)
	        set_notifications_number(settings)
	      end
	      return  '/file/' + doc + '.pdf'
	    else
	      raise ArgumentError.new("redirect")
	    end
	end

	def self.setDocuments(user)
    	mydocs = user.documents_dataset.where(delete: false)
        mydocstaged = mydocs.select(:document_id).where(motive: 'taged')
        mydocstagedsubs = mydocs.select(:document_id).where(motive: 'taged and subscribed')
        if mydocstagedsubs.union(mydocstaged).count.positive?
        	return Document.where(id: mydocstagedsubs.union(mydocstaged))
        end
	end

	def self.set_unread_number()
	    if @current_user
	      getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
	      documents = Document.select(:id).where(id: getdocs, delete: false)
	      @unread = Notification.where(user_id: @current_user.id, document_id: documents, read: false).to_a.length
	    end
    end


	  def self.cant_pages(docs)
	    @docsperpage = 12
	    
	    if docs 
	    	cantdocs = docs.count
	   	else
	   		cantdocs = 0
	   	end

	    if (cantdocs % @docsperpage).zero?
	        return  cantdocs / @docsperpage
	    else
	        return cantdocs / @docsperpage + 1
	    end
	  end

	  def self.set_page(pageP)
	    page = pageP || '1'
	    return page
	  end

	def self.editDoc(category, editdoc, date, title, users, categories, settings)
	    doc = Document.new(date: date, name: title, userstaged: array_to_tag(users),
	                       categorytaged: categories, category_id: category.id, document: editdoc.document)
	    if doc.save
	      editdoc.update(delete: true)
	      set_notifications_number(settings)
	      tag(users, doc)
	    else
	      set_unread_number
	      Raise ArgumentError.new("An error has ocurred when trying edit the document")
	    end
	end

	def self.set_notifications_number(settings)
	    settings.sockets.each do |s|
	      getdocs = Notification.select(:document_id).where(user_id: s[:user])
	      documents = Document.select(:id).where(id: getdocs, delete: false)
	      unread = Notification.where(user_id: s[:user], document_id: documents, read: false).to_a.length
	      s[:socket].send(unread.to_s)
	    end
	end

	def self.array_to_tag(users)
	    if users && users != ''
	      tagged_users = ''
	      users.each do |s|
	        tagged_users += if s.equal?(users.last)
              s
            else
              s + ', '
            end
	    end
	    tagged_users
    	end
    end

    def self.docs(remove, userfilter, datefilter, categoryfilter, page, settings)
    	docsperpage = 12
    	pageP = set_page(page)
	    if remove
	        Document.first(id: remove).update(delete: true)
	        set_notifications_number(settings)
	    end

	    if userfilter || datefilter || categoryfilter
	      cargdocs = filter(userfilter, datefilter, categoryfilter)
	      return cargdocs[((pageP.to_i - 1) * docsperpage)..(pageP.to_i * docsperpage) - 1]
	    else
	      return Document.where(delete: false).limit(docsperpage, (docsperpage * pageP.to_i ) - docsperpage ).order(:date).reverse
	    end

	    set_unread_number() 

    end

    def filter(userfilter, datefilter, categoryfilter)
	    filter_docs = []
	    user = User.first(username: userfilter)

	    if user
	      filter_docs = user.documents_dataset.where(motive: 'taged', delete: false).order(:date).to_a
	      filter_docs += user.documents_dataset.where(motive: 'taged and subscribed', delete: false).order(:date).to_a
	    else
	      filter_docs = Document.where(delete: false).order(:date).reverse.all
	    end
	    doc_date = datefilter == '' ? filter_docs : Document.first(date: datefilter)
	    filter_docs = if doc_date
	                    datefilter == '' ? filter_docs : filter_docs.select { |d| d.date == doc_date.date }
	                  else
	                    []
	                  end
	    category = Category.first(name: categoryfilter)
	    filter_docs = categoryfilter == '' ? filter_docs : filter_docs.select { |d| d.category_id == category.id }
	    filter_docs
	end

	def self.upload(date, title, categories, document, settings, users)
		if date != '' && title != '' && categories != '' && document != ''
	      file = document[:tempfile]
	      @filename = document[:filename]

	      @src = "/file/#{@filename}"

	      category = Category.first(name: categories)

	      doc = Document.new(date: date, name: title, userstaged: array_to_tag(users),
	                         categorytaged: categories, document: @src, category_id: category.id)

	      if doc.save
	        doc.update(document: doc.id)
	        FileUtils.cp(file.path, "public/file/#{doc.id}.pdf")

	        #tag(users, doc, body)

	        set_notifications_number(settings)

	        set_unread_number

	        return doc
	      else
	        raise ArgumentError.new('An error has ocurred when trying to upload the document')
	      end
	    end

	end

	

	

end