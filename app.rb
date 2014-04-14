require 'sinatra'
require 'sinatra/flash'
require 'data_mapper'
require 'haml'
require 'redcarpet'
require 'builder'


SITE_TITLE = "Recall"
SITE_DESCRIPTION = "Because you always forget to remember"

configure do
	enable :sessions
	set :session_secret, "xXtv6ReGcMRmFSgXGiHXqnrpOscpi8WaYXcer6oFYaK2PbMPBvriC7Lu0YrFsJA"
  DataMapper.setup(:default, ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/development.sqlite3")
end

class Note
	include DataMapper::Resource
	property :id, Serial
	property :content, Text, required: true
	property :complete, Boolean, required: true, default: false
	property :created_at, DateTime
	property :updated_at, DateTime
end

DataMapper.finalize.auto_upgrade!

helpers do
	def h(input)
		Rack::Utils.escape_html(input)
	end
end

set(:method) do |method|
  method = method.to_s.upcase
  condition { request.request_method == method }
end

before method: :post do
	if Note.all.count >= 5
		redirect "/", flash[:error] = "You have 5 notes already. Delete one first."
	end
end

get "/" do
	@notes = Note.all order: :id.desc
	@title = "All Notes"
	if @notes.empty?
		flash[:error] = "No notes found. Add your first one below."
	end
	haml :home
end

get "/rss.xml" do
	@notes = Note.all order: :id.desc
	builder :rss
end

post "/" do
	note = Note.new
	note.content = markdown params[:content]
	note.created_at = Time.now
	note.updated_at = Time.now
	if note.save
		redirect "/", flash[:notice] = "Note created successfully"
	else
		redirect "/", flash[:error] = "Failed to save note"
	end
end

get "/:id" do
	@note = Note.get params[:id]
	@title = "Edit note ##{params[:id]}"
	@checked_value = @note.complete ? true : false
	if @note
		haml :edit
	else
		redirect "/", flash[:error] = "Can't find that note"
	end
end

put "/:id" do
	note = Note.get params[:id]
	note.content = params[:content]
	note.complete = params[:complete] ? 1 : 0
	note.updated_at = Time.now
	if note.save
		redirect "/", flash[:notice] = "Note updated successfully"
	else
		redirect "/", flash[:error] = "Error updating note"
	end
end

get "/:id/delete" do
	@note = Note.get params[:id]
	@title = "Confirm deletion of note ##{params[:id]}"
	if @note
		haml :delete
	else
		redirect "/", flash[:error] = "Can't find that note"
	end
end

delete "/:id" do
	note = Note.get params[:id]
	if note.destroy
		redirect "/", flash[:notice] = "Note deleted successfully"
	else
		redirect "/", flash[:error] = "Error deleting note"
	end
end

get "/:id/complete" do
	note = Note.get params[:id]
	unless note
		redirect "/", flash[:error] = "Can't find that note"
	end
	note.complete = params[:complete] ? 0 : 1
	note.updated_at = Time.now
	if note.save
		redirect "/", flash[:notice] = "Note marked as complete"
	else
		redirect "/", flash[:error] = "Error completing note"
	end
end
