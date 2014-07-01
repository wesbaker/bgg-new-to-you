BoardGameGeek New to You Script
===============================

Every month I participate in the [New to You
Geeklists](http://boardgamegeek.com/geeklist/51617/new-to-you-metametalist) on
[BoardGameGeek](http://boardgamegeek.com/) and after a while I realized that
the research I was doing was easily reproduced by a script, hence this
repository.

Installing
----------

First and foremost, you'll need at least Ruby 1.9.2 due to Nokogiri. After that,
you should use [bundler](http://bundler.io) to install the required gems:

    bundle install

You might also have to change permissions to make the script executable:

    chmod +x bgg-new-to-you.rb

Using
-----

Once everything's loaded, run the script like so:

    ./bgg-new-to-you.rb --username <your_username>

By default the script will retrieve plays for the past month, if you need to
pick a different month or year you can:

    ./bgg-new-to-you.rb --username <your_username> --month 7 --year 2012
