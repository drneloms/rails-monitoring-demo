class HelloController < ApplicationController
  def index
    render plain: "Hello World from Rails + PostgreSQL + Redis!"
  end
end
