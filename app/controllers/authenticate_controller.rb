class AuthenticateController < ApplicationController

  before_action :confirm_logged_in, :except =>[:login, :logout, :attempt_login]

  def confirm_logged_in
  	session[:username]=nil
  end

  def login
    @branch = Area.all
    render layout: 'loginlayout'
  end

  def logout
  	session.clear
  	redirect_to(:action=>'login')
  end

  def attempt_login
    @connection = ActiveRecord::Base.connection
    user = Session.find_by(:userName=>params[:user])
    if user
      if user.userName == 'amd'
        pw = Session.find_by(:userName=>params[:user],:passWord=>params[:password])
      else        
        pw = Session.find_by(:userName=>params[:user],:passWord=>params[:password], :branch=> params[:branch])
      end

      if pw
        session[:username]= pw.userName
        role_id = pw.privilege.id
        session[:role]= pw.privilege.privilege
        session[:branch] = params[:branch]
        acct = Employee.find_by(:idEmp=> user.idEmp)
        if acct
          session[:acctname] = acct.fName + ' ' + acct.midInit + '. ' + acct.lName 
        else
          session[:acctname] = session[:username]
        end
        redirect_to main_index_path
      else
        flash[:notice] = "Username and password did not match."
        redirect_to(:action=>'login')
      end
    else
      flash[:notice] = 'Your Username is not recognized. Sign in or sign up first.'
      redirect_to(:action=>'login')
    end
  end
end


