class AuthenticateController < ApplicationController
  
  before_action :confirm_logged_in, :except =>[:login, :logout, :attempt_login]

  def confirm_logged_in
  	session[:username]=nil
  end

  def login
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
      pw = Session.find_by(:userName=>params[:user],:passWord=>params[:password])
      if pw
          session[:username]= pw.userName
          role_id = pw.privilege.id
          session[:role]= pw.privilege.privilege
          
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


