#!/usr/bin/env ruby

# Plans
# - Break up things into individual files and use the /lib directory? Try to
#   find examples of this
# - Provide a way to do the year ago posts, duplicating code at first is fine
# - Refactor so both calls use the same code
# - Color code the ratings using BGG's colors
#   - 10/10 #00cc00
#   - 9/10  #33cc99
#   - 8/10  #66ff99
#   - 7/10  #99ffff
#   - 6/10  #9999ff
#   - 5/10  #cc99ff
#   - 4/10  #ff66cc
#   - 3/10  #ff6699
#   - 2/10  #ff3366
#   - 1/10  #ff0000

require 'date'
require 'optparse'
require 'open-uri'
require 'nokogiri'
require './game'

class NewToYou
  def initialize
    last_month = Date.today << 1
    @options = {
      :username     => 'wesbaker',
      :month        => last_month.month,
      :year         => last_month.year,
    }

    parse_options

    # Establish previous start and end dates
    last_month = Date.new(@options[:year], @options[:month])
    @options[:start_date] = (last_month - 1).to_s

    # last_month >> 1 gets the same time as above + 1 month, - 1 subtracts a day
    @options[:end_date] = ((last_month >> 1) - 1).to_s

    print_plays(retrieve_plays())
  end

  # Parse out command line options
  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Retrieve a listing of games that were new to you.
    Usage: bgg-new-to-you.rb --username wesbaker --month 6"

      opts.on('-u username', '--username username', "Username") do |username|
        @options[:username] = username.to_s
      end

      opts.on('-m MONTH', '--month MONTH', "Month (numeric, e.g. 5 or 12)") do |month|
        @options[:month] = month.to_i
      end

      opts.on('-y YEAR', '--year YEAR', 'Year (four digits, e.g. 2013)') do |year|
        @options[:year] = year.to_i
      end
    end.parse!
  end

  def retrieve_plays(start_date = @options[:start_date], end_date = @options[:end_date], username = @options[:username])
    # Retrieve games played in month
    plays = BGG_API.new('plays', {
      :username => username,
      :mindate  => start_date,
      :maxdate  => end_date,
      :subtype  => 'boardgame'
    }).retrieve

    _games = Hash.new

    # First, get this month's plays
    plays.css('plays > play').each do |play|
      quantity = play.attr('quantity')
      item = play.search('item')
      name = item.attr('name').content
      objectid = item.attr('objectid').content.to_i

      # Create the hashes if need be
      unless _games.has_key? objectid
        _games[objectid] = Game.new
        _games[objectid][:objectid] = objectid
        _games[objectid][:name] = name
      end

      # Increment play count
      _games[objectid][:plays] = _games[objectid][:plays] + quantity.to_i
    end

    _games.each do |objectid, data|
      # Filter out games I've played before (before mindate)
      previous_plays = BGG_API.new('plays', {
        :username => username,
        :maxdate  => start_date,
        :id       => objectid
      }).retrieve

      if previous_plays.css('plays').first['total'].to_i > 0
        _games.delete(objectid)
        next
      end

      # Now, figure out what my current ratings and plays for that game is
      game_info = BGG_API.new('collection', {
        :username => username,
        :id       => objectid,
        :stats    => 1
      }).retrieve

      # Error out
      if not game_info.at_css('rating')
        game_info = BGG_API.new('thing', {
          :id       => objectid
        }).retrieve
        name = game_info.css('name').first['value']
        puts "#{name} not rated. Rate the game and run this script again:"
        puts "\thttp://boardgamegeek.com/collection/user/#{username}?played=1&rated=0&ff=1"
      end

      if game_info.at_css('rating').is_a? Nokogiri::XML::Element
        _games[objectid][:rating] = game_info.css('rating').attr('value').content.to_i
        _games[objectid][:comment] = game_info.css('comment').text
        _games[objectid][:imageid] = game_info.css('image').text.match(/\d+/)[0].to_i

        #Figure out plays since
        total_plays = game_info.css('numplays').first.text.to_i
        _games[objectid][:plays_since] = total_plays - _games[objectid][:plays]
      else
        _games[objectid][:rating] = 0
        _games[objectid][:comment] = ''
        _games[objectid][:plays_since] = 0
      end
    end

    # Sort games by rating
    _games.sort_by { |objectid, data| data[:rating] * -1 }
  end

  def print_plays(_games)
    # Spit out something coherent
    _games.each do |objectid, data|
      data[:stars] = ':star:' * data[:rating] + ':nostar:' * (10 - data[:rating])
      data[:play_count] = play_count(data[:plays], data[:plays_since])
      puts data.render
    end
  end

  def play_count(plays, since)
    text = "#{plays} play"
    text += 's' if plays > 1
    text += ", #{since} since" if since > 0
    text
  end

  public :initialize
  private :parse_options, :retrieve_plays, :print_plays, :play_count
end

# BGG API class that pulls in data and takes a hash as a set of options for the
# query string
class BGG_API
  @@bgg_api_url = "http://boardgamegeek.com/xmlapi2"

  def initialize(type, options)
    @type = type
    @options = options
  end

  def set_options(options)
    @options = @options.merge(options)
  end

  def retrieve
    query = "#{@@bgg_api_url}/#{@type}?"

    @options.each do |name, value|
      query << "#{name}=#{value}&"
    end

    # Make sure we're receving a 200 result, otherwise wait and try again
    request = open(query)
    while (request.status[0] != "200")
      sleep 2
      request = open(query)
    end

    Nokogiri::XML(request.read)
  end
end

NewToYou.new
