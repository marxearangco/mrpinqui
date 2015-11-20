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
          session[:username]=user.userName
          session[:role_id] = user.privilege
          @get_role = @connection.execute("select * from tblprivilege where id = '#{session[:role_id]}'")
          @get_role.each do |role|
            session[:role] = role["privilege"]
          end
          acct = Employee.find_by(:idEmp=> user.idEmp)
          if acct
          	session[:acctname] = acct.fName + ' ' + acct.midInit + '. ' + acct.lName 
          else
            session[:acctname] = 'Logout'
          end
          redirect_to main_index_path
      else
        if params[:password]==user.passWord
          cond = 'true'  
        else 'false'
          cond = 'false'
        end
        flash[:notice] = "Username and password did not match."
         # + ' ' + cond + ' ' + user.passWord
        # user.passWord + ' ' + user.userName + ' ' + user.privilege
        # 
        redirect_to(:action=>'login')
      end
    else
      flash[:notice] = 'Your Username is not recognized. Sign in or sign up first.'
      redirect_to(:action=>'login')
    end
  end

end


