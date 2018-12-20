# Nexy

## What does Nexy do?

Currently Nexy has the following skills:

1. Looking up words in the dictionary (Merriam-Webster.  Requires API key)
1. Translating Jira numbers to Jira ticket links
1. Conducting raffles

## How do I start up Nexy for development?

* Add your slack token to `slackbot-frd.conf` in the provided spot (or set it as an env var, which is recommended for production environments).  For more information see [the slackbot_frd documentation](https://github.com/FreedomBen/slackbot_frd#prestantious--eximious--how-do-i-start)
* Add your Merriam Webster dictionary keys to `slackbot-frd.conf` (or the env var) if you want to use the dictionary bot
* run `bundle install`
* run `slackbot-frd start` from the top-level directory

## Can I send pull requests?

Please do!

## What framework does this use?

Nexy uses [slackbot_frd](https://github.com/FreedomBen/slackbot_frd)

## Running in production

### Provisioning the VM

Any VM service provider will do.  Nexy runs in docker, and has been hosted on Digital Ocean and AWS EC2 at various times.  The important part is that you install docker on your base image.  Once docker is installed, clone this repo:

```bash
git clone https://github.com/FreedomBen/nexy.git
```

You will also probably want to install some additional tools on the system, such as `tmux`
(which is useful for maintaining the session after the SSH connection is closed.
Instructions in this guide will assume you are using tmux, with the provided `tmux.conf`
file installed at `$HOME/.tmux.conf` (you can use the script `./dotfiles/update-dot-files.sh`
to do this for you, but be advised it will stomp on existing files (which you probably don't
want to do on your dev machine, only on the nexy server)).

### Building/Starting the instance

#### Building

There is a handy script located at `scripts/build.sh` that will build you an image of nexy that you can then run with the other script (see [Starting](#starting)).  Call it from the root of the project like this:

```bash
./scripts/build.sh
```

Alternatively you can build it manually from the project root by running:

```bash
docker build -t nexy .
```

This builds an image named "nexy".  If you give it a different name, you'll need to make note of that for when you run the image as a container.

#### Starting

_NOTE: The tmux portion is optional, but recommended_

If you're not in a `tmux` session yet, kick one off:

```bash
tmux
```

Or if one already exists, find it and attach to it:

```bash
tmux ls           # list current sessions
tmux at -t <num>  # attach to session <num> e.g:  0
```

Check out the [tmux](#tmux-tips) section for a quick rundown of common tmux things that are handy.

Once the image is [built](#building), you can run it with the handy script:

```bash
./scripts/run-container.sh
```

or manually using:

```bash
docker run -it --rm --name nexy nexy bash
```

_NOTE:  The reason we are calling `bash` in the container is because currently the decryption key to unlock the secrets must be typed in manually._

Once the container is running, use the `start` alias to kick things off.  It will prompt you for the decryption key (password) which you will need to enter:

```bash
$ start
Enter password:
```

Nexy should now be running!  If you're curious about implementation, read on for some explanation.

The `start` alias is defined in the `Dockerfile` as a shortcut to calling:

```bash
/app/scripts/start-bots.sh
```

The `scripts/start-bots.sh` script will call `aescrypt` to decrypt the secrets file and source the contents into the current shell, then start `slackbot-frd` for you.  All it does is call:

```bash
. <(aescrypt -d nexy.aes -o -) || echo 'Doh password was wrong'
slackbot-frd start
```

##### Restarts and ping/pong

The underlying [slackbot_frd](https://github.com/FreedomBen/slackbot_frd) library uses ping/pong
signals to ensure that the connection is still up.  This is good because every once in a while
slack will stop responding on the other end, but the socket is never closed.  Without a ping/pong
check, nexy will happily continue running thinking everything is fine, when in fact it is not.

If the slack server fails to answer the "ping" message with a "pong" after a few seconds,
[slackbot_frd](https://github.com/FreedomBen/slackbot_frd) will tear down the connection and
restart it.  This has successfully been done for years now in production.

Occasionally however, something strange will happen and you will need to manually restart nexy.
When this occurs, simply navigate to the running window (in tmux for example) and Ctrl+C the instance,
then restart it with normal procedure of running `start`

#### Deploying changes/Updating the source code

Deploying changes is as simple as SSHing in to the VM, then change to the code directory and run:

```bash
git pull --rebase
./scripts/build.sh
```

Then attach to the tmux session and restart the container:

```bash
tmux at  # if not already attached
# <Ctrl+c> in running window
./scripts/run-container.sh
start
# Enter password
```

#### tmux tips

Start a new session:

```bash
tmux
```

Attach to existing session:

```bash
tmux ls           # list current sessions
tmux at -t <num>  # attach to session <num> e.g:  0
```

Detach from session:

```
<Ctrl+b> d
```

Split current pane horizontally:

```
<Ctrl+b><Ctrl+d>
```

Split current pane vertically:

```
<Ctrl+b><Ctrl+s>
```

Navigate panes:

```
<Ctrl+b> h   # h, j, k, l for left, up, down, or right (like vim)
```

### Modifying the secrets file `nexy.aes`:

If you need to add, update, or delete a value in the secrets file, this is not hard.  It does require [aescrypt](https://www.aescrypt.com/) CLI tool to be installed on your machine.  You can peek at the `Dockerfile` for hints on how to install it.  On Fedora, you just need to install dependencies:

```bash
sudo dnf install unzip glibc glibc-devel glibc-static
```

Then pull down, build, and install:

```bash
cd ~   # or wherever you prefer
wget https://github.com/FreedomBen/aescrypt/archive/master.zip
unzip master.zip
cd aescrypt-master/linux/src
make
sudo make install
```

Now decrypt the secrets file

```bash
aescrypt -d nexy.aes
```

Enter the decryption key when prompted for the password.  Once decrypted open the new file `nexy` in the editor of your choice and make your modifications.

*IMPORTANT:  You must stick to legal bash syntax since the contents of this file are sourced into a bash shell in the nexy container*

Now re-encrypt the file, being very careful not to fat-finger the key:

```bash
aescrypt -e nexy
```

`rm` the plaintext file and commit your updated version to the repo.

_TIP:  If you just want to view the contents of the file, you can print it to the terminal with:_

```bash
aescrypt -d -o - nexy.aes
```

_Keep in mind tho that the contents will stick around in the tmux buffer so be discriminating about where you do this._

### Periodic Maintenance

#### Installing updates

If running on Amazon Linux, Red Hat, CentOS, or other related distro, use:

    sudo yum update

*NOTE:* **If the update installs a new docker engine (which it does from time to time), it will kill all running docker containers which includes nexy, and she'll need to be restarted again**

#### Cleaning up docker artifacts

Periodically, after starting/stopping docker containers, you may want to clean up artifacts left by docker.  This will prevent the disk from filling up.  There are a few things you should do:

1.  Cleanup unlabeled images (often build artifacts)

```bash
docker rmi $(docker images | grep -iE '^<none>' | awk '{print $3}' | xargs)
```

1.  Cleanup old containers (nexy containers shouldn't accumulate, but still good to check)

#### Scaling

_Note:  This is a glimpse into the distant future and isn't relevant now, but might be at some point, so I've included it here as part of my brain dump_

Currently a single angel bot instance more than meets the demand at Instructure.  In the future it's possible that this may change.  Due to underlying libraries, angel runs on a single thread, and there isn't really a vertical scaling option.  Fortunately I foresee a few strategies for scalining horizontally, which is the better way to scale anyway.

1.  Multiple instances of nexy on the same EC2 instance
1.  Multiple EC2 instances running one or more instances of nexy

The way it is currently, running _n_ instances of angel bot will result in _n_ responses to every trigger.  This is obviously terrible.  To correct this, there are a couple strategies to choose from (ordered by what sound like the best options to me currently):

1.  Have each instance only answer some non-intersecting subset of channels:  E.g.:  Instance 0 is listening in channels a, b, and c (busy channels) while Instance 1 listens in all other channels
    - To accomplish this, you will need to modify the bot code to check for the appropriate channel.  There a couple of ways to do this.  See `greeting-bot.rb` for a good example (it uses slackbot_frd to do the filtering rather than checking `channel == 'mychannel'`.  If using a subset tho, I don't think currently works with slackbot_frd so you might need to do something like `if %w[c1, c2].include?(channel)`
1.  Have each instance run a non-intersecting subset of bots.  E.g. Instance 0 runs the gerrit-jira translator (main source of traffic) and instance 1 runs all the others

_NOTE:  The scripts in `scripts/*` will need to be modified to use different container name based on the instance, because currently if starting multiple instances on the same docker daemon, there will be a name conflict_



