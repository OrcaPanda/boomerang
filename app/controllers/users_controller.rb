class UsersController < ApplicationController

	skip_before_filter :verify_authenticity_token, :only => :create
#	protect_from_forgery :except => :create

  before_action :set_user, only: [:show, :edit, :update, :destroy]
  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)
    if @user.save
    	redirect_to root_url
    else
    	render 'new'
    end
  end

#	def create
#		@user = User.new(user_params)
#		respond_to do |format|
#		if @user.save
#			format.html {redirect_to @user, notice: 'User was successfully created'}
#			format.json {render action: 'index'}
#		else
#			format.html { render action: 'new'}
#			format.json { render json: @user.errors}
#		end
#		end
#	end

  def update
	if @user.update(user_params)
		redirect_to @user      
	else
		render 'edit'
	end
  end

  def destroy
  	@user.destroy
	redirect_to users_url
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:name, :surname, :email, :password, :password_confirmation)
    end
end
