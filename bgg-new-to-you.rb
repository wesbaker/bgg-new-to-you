#!/usr/bin/env ruby

require 'date'
require 'optparse'
require 'open-uri'
require 'nokogiri'
require './game'

class NewToYou
  def initialize
    last_month = Date.today << 1
    @options = {
      :bgg_api_url  => "http://boardgamegeek.com/xmlapi2",
      :username     => 'wesbaker',
      :month        => last_month.month,
      :year         => last_month.year
    }

    parse_options

    # Establish previous start and end dates
    last_month = Date.new(@options[:year], @options[:month])
    @options[:start_date] = last_month.to_s
    @options[:end_date] = ((last_month >> 1) - 1).to_s

    _plays = retrieve_plays
    print_plays(_plays)
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

  def retrieve_plays
    # Retrieve games played in month
    plays = Nokogiri::XML(open("#{@options[:bgg_api_url]}/plays?username=#{@options[:username]}&mindate=#{@options[:start_date]}&maxdate=#{@options[:end_date]}&subtype=boardgame").read)

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

    # Now, figure out what my current ratings and plays for that game is
    collection = Nokogiri::XML(open("#{@options[:bgg_api_url]}/collection?username=#{@options[:username]}&played=1&stats=1").read)

    _games.each do |objectid, data|
      # Filter out games I've played before (before mindate)
      previous_plays = Nokogiri::XML(open("#{@options[:bgg_api_url]}/plays?username=#{@options[:username]}&maxdate=#{@options[:start_date]}&id=#{objectid}").read)

      if previous_plays.css('plays').first['total'].to_i > 0
        _games.delete(objectid)
        next
      end

      game_info = collection.css("item[objectid='#{objectid}']")
      next if game_info.empty?
      _games[objectid][:rating] = game_info.css('rating').attr('value').content.to_i

      total_plays = game_info.css('numplays').first.text.to_i
      _games[objectid][:plays_since] = total_plays - _games[objectid][:plays]
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

NewToYou.new