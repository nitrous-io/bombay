# Setting up a development box

The following are the steps to create an action.io development box on an AWS EC2 instance.

## Initial Setup

Create an EC2 instance on AWS. Assign an __elastic ip__ to it

Update the instance. You can use [apt-get](http://superuser.com/questions/198838/apt-get-vs-aptitude?lq=1) as well.
```
sudo aptitude update
sudo aptitude full-upgrade
```

Create your own user
```
sudo adduser foo
```

Add the user to the admin group
```
sudo usermod -a -G admin foo
```

Change the sudo rules so that the user does not need a password for running sudo. We need this as boxer needs to run sudo commands. Update the admin rule in __visudo__
```
%admin ALL=(ALL) NOPASSWD: ALL
```

Add your own ssh keys to the user account(intentionally left blank)

Install dependencies
```
sudo aptitude install git-core tmux build-essential libxslt-dev libxml2-dev libqt4-dev
```

Create the ansible configuration file
```
touch ~/.ansible_hosts
```

__ansible_hosts__ should contain
```
127.0.0.1
```

Add the following environment variables to your shell configuration.
```
export ANSIBLE_HOSTS=/home/zan/.ansible_hosts
export LC_CTYPE=en_US.UTF-8
```

Add __dev.action.io__ to /etc/hosts
```
127.0.0.1 dev.action.io
```

Install RVM
```
\curl -L https://get.rvm.io | bash -s stable --ruby
```

You may choose to reboot at this point in time

Next we want to clone the bombay project as it contains the script necessary to setup the development environment.

Assuming your project directory is called 'Projects',

```
cd Projects
git clone git@github.com:action-io/bombay.git
cd bombay
bundle install
./bin/bombay setup
```

That should setup ansible. Next we will start building the box using ansible. Assuming you are on the __bombay__ directory.

```
ansible-playbook ansible/servers/development/plays/main.yml
```

That should initiate the playbook to build the environment.

Once done, go to the __action.io__ directory,

```
bundle install
export $(cat .env) &&  bundle exec rake db:migrate
export $(cat .env) &&  bundle exec rake db:seed
```

Next you have to change some variables using the rails console. Log into rails console and run the following.

``` ruby
i = Invite.new
i.email = 'foo@action.io'
i.save
i.activate!
r = Region.all
r = Region.find(5)
r.enabled = true
r.box_server_uri = 'https://dev.action.io:5001'
r.coach_uri = 'http://dev.action.io:5002'
r.save
```

Download the [ssh tunnel](http://www.macupdate.com/app/mac/10128/ssh-tunnel-manager). And use the settings from attached image.

![SSH Tunnel Settings](https://raw.github.com/action-io/bombay/dev-box/ansible/servers/development/ssh_tunnel.png?login=liangzan&token=e6057bb393838c11773540138ed3a2a1)

Next run boxer, coach, rainbow and action.io individually using the command

```
./script/server
```

Once all are running, visit the site at https://dev.action.io:5000. You should see the site running.

To log in, go to http://dev.action.io:5000/users/sign_up. Use the invite code from the invite object you created in the rails console.
