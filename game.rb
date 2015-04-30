require 'mustache'

class Game < Mustache
  self.template_path = File.dirname(__FILE__)

  def name
    'Game'
  end

  def plays
    0
  end

  def plays_since
    0
  end

  def rating
    0
  end

  def play_count
    '1 play'
  end

  def stars
    ''
  end

  def imageid
    0
  end
end
