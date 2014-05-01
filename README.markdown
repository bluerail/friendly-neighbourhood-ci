Your friendly neighbourhood continues integration annoyer
=========================================================
Simple Ruby continues integration script. It's fairly *simple* &
straightforward, and should *just work*™.

Basic usage:

- `git clone myrepo myrepo.repo`
- `git clone another another.repo`
- `./ci.rb`
- *sit still and be amazed*


Default settings can be added per repo in `$repo/.ci-settings.yaml`, an example
might be:

    testcmd: |
      vagrant up
      vagrant ssh -c 'cd /vagrant && bundle install'
      vagrant ssh -c 'cd /vagrant && bundle exec rake'
      vagrant halt
    from: CI annoyer <ci@lico.nl>'
    mailto: martin@arp242.net,%a,%c


TODO: Properly document this ... :-/

**Warning** We run `git pull --force` on every repo. You probably do not want to
use this in repo's you're actually working in.
