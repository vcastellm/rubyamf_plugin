#Copyright (c) 2007 Aaron Smith (aaron@rubyamf.org) - MIT License

#this class is a simple DB error logging class
#generally in a service method, you want to wrap anything you can with begin / rescue clauses to catch exceptions
#if a DB error happens use this Static class to log it. Also use the ErrorNotifier class to send yourself an email foo.
=begin
EX:

class MyService
  def before_filter
    begin
      @con = Mysql.connect('localhost','root','')
      @con.select_database('somedb')
    rescue Exception => e
      DBErrorLogger.Log([e])
    end
  end

  def getMysqlResult
    begin
      @con.query("SELECT * FROM some_table")
    rescue Mysql::Error => me
      DBErrorLogger.Log([me],['logs/db_errors/MyService.log'])
    end
  end
=end

class DBErrorLogger  
  def DBErrorLogger.Log(data, location = RUBYAMF_CORE + 'logs/db_errors/all_services.log')
    File.open(location, 'a') do |f|
      if(data.class.to_s == "String")
        d = Time.now.to_s
        f.puts '::' + d + "\n" + obj.to_s
      elsif data.class.to_s == 'Array'
        d = Time.now.to_s
        f.puts '::' + d
        data.each do |obj|
          f.puts obj.to_s
        end
      end
    end
  end
end