# config.rb
class Config
    attr_accessor :username, :api_key, :url
    
    def initialize(api_key=nil, username=nil)
      @username           = username
      @api_key            = api_key
      @url                = "https://api.tumblr.com/v2/blog/#{@username}.tumblr.com/likes?api_key=#{@api_key}"
    end
  end
  