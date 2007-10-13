#Copyright (c) 2007 Aaron Smith (aaron@rubyamf.org) - MIT License

require 'net/smtp'

#this helper is used for sending emails when errors occur in your services. It's pretty basic but it's always good to be notified of errors
#See the 'net/smtp' ruby docks for more smtp info.

class ErrorNotifier
  def ErrorNotifier.Send(smtpp, to, from, data = nil)
    if to == nil || from == nil
      raise Exception.new("You must supply To and From to use ErrorNotifier")
    end
    
    msgstr = 'RubyAMF Service Error'
    if data.class.to_s == 'String'
      msgstr = data
    elsif data.class.to_s == 'Array'
      data.each do |item|
        msgstr = item.to_s + "\n"
      end
    end
    
    #Basic SMTP mailer
    #Net::SMTP.start('smtp.gmail.com', 25, 'pop.gmail.com','email', 'pass', :login) do |smtp|
    #  smtp.send_message msgstr, from, to
    #end
    
    #Net::SMTP.start('localhost', 25) do |smtp|
    #  smtp.send_message msgstr, from, to
    #end
  end
end

#Other net/smtp examples:

=begin
    Net::SMTP.start('smtp.example.com', 25) do |smtp|
      smtp.open_message_stream(from, to) do |f|
        tostrong = to.map{|email| return "'#{email}'"}
        f.puts "#{from}"
        f.puts "To:" + String(tostring.join(','))
        f.puts 'Subject: RubyAMF error'
        f.puts
        f.puts "'#{msgstr}'"
      end
    end
=end


=begin
PLAIN
Net::SMTP.start('your.smtp.server', 25, 'mail.from.domain',
                'Your Account', 'Your Password', :plain)
LOGIN
Net::SMTP.start('your.smtp.server', 25, 'mail.from.domain',
                'Your Account', 'Your Password', :login)

CRAM MD5
Net::SMTP.start('your.smtp.server', 25, 'mail.from.domain',
                'Your Account', 'Your Password', :cram_md5)
=end