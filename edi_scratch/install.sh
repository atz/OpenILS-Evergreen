#!/bin/bash
#
# JEDI converter scripts installation
#
# Debian Lenny dependencies
#
# The rubygems package from Debian apt sources is crippled and cannot update.
# The result is that we need to replace it with the current version.


# apt-get install libgemplugin-ruby  # recommended by some pages as a workaround, but already satisfied by ruby-full
sudo apt-get install ruby-full ruby-dev rubygems    # maybe ruby-full is overkill?
sudo gem install rubygems-update                    # maybe unnecessary if we do ruby setub.rb below

# runaround for debian's crippled rubygems package:
mkdir rubygems
pushd rubygems
svn checkout svn://rubyforge.org/var/svn/rubygems/trunk
cd trunk
sudo update_rubygems
# ruby setup.rb
popd

sudo gem install rspec edi4r json rcov # mkmf

