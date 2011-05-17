#!/bin/bash



# load variables and constants
source ./options.conf
source ./constants.conf

# client-side git administrator stuff
git_admin_user_name="unforgiven512"
git_admin_user_pubkey="PUBKEY GOES HERE"

# git/team/gitadmin passwords
password_user_git="Change_m3"
password_user_team="Change_m3"
password_user_gitadmin="Change_m3"

# install git, git-doc, gitweb
aptitude -y install git git-doc gitweb

# setup git users
touch /tmp/gitusers
echo "git:$password_user_git::::/home/git:/bin/bash" >> /tmp/gitusers
echo "team:$password_user_team::::/home/team:/bin/bash" >> /tmp/gitusers
echo "gitadmin:$password_user_gitadmin::::/home/gitadmin:/bin/bash" >> /tmp/gitusers
newusers /tmp/gitusers
shred /tmp/gitusers
rm /tmp/gitusers

# make ssh key for gitadmin
sudo -u gitadmin mkdir -p /home/gitadmin/.ssh
sudo -u gitadmin ssh-keygen -t rsa -N "" -f /home/gitadmin/.ssh/id_rsa

# copy and set perms
cp /home/gitadmin/.ssh/id_rsa.pub /tmp/gitadmin.pub
chmod 0666 /tmp/gitadmin.pub

# copy example.gitolite.rc into homedirs for git/team
cp /usr/local/share/gitolite/conf/example.gitolite.rc /home/git/.gitolite.rc
cp /usr/local/share/gitolite/conf/example.gitolite.rc /home/team/.gitolite.rc

# create git/team repo base
mkdir -p /srv/git/{public,private}

# set ownership
chown git:git /srv/git/public
chown team:team /srv/git/private

# change git/team repo base
sed -i 's/\$REPO_BASE=\"repositories\";/\$REPO_BASE=\"\/srv\/git\/public\";/' /home/git/.gitolite.rc
sed -i 's/\$REPO_BASE=\"repositories\";/\$REPO_BASE=\"\/srv\/git\/private\";/' /home/team/.gitolite.rc

# set ownership
chown git:git /home/git/.gitolite.rc
chown team:team /home/team/.gitolite.rc

# setup gitolite for both
sudo -u git gl-setup /tmp/gitadmin.pub
sudo -u team gl-setup /tmp/gitadmin.pub

# make gitadmin directories
sudo -u gitadmin mkdir -p /home/gitadmin/{private,public}

# set ownership
chown gitadmin:gitadmin /home/gitadmin/{private,public}

# configure git
su - gitadmin -c "git config --global user.name \"Server Git Administrator\""
su - gitadmin -c "git config --global user.email gitadmin@$HOSTNAME_FQDN"

# checkout gitolite-admin repositories
su - gitadmin -c "git clone git@localhost:gitolite-admin /home/gitadmin/public"
su - gitadmin -c "git clone team@localhost:gitolite-admin /home/gitadmin/private"

# copy client-side admin's pubkey into admin directories
echo "$git_admin_user_pubkey" > "/tmp/$git_admin_user_name.pub"
cp "/tmp/$git_admin_user_name.pub" /home/gitadmin/private/keydir/
cp "/tmp/$git_admin_user_name.pub" /home/gitadmin/public/keydir/
chown gitadmin:gitadmin "/home/gitadmin/{private,public}/keydir/$git_admin_user_name.pub"

# rebuild gitolite.conf for each user
rm /home/gitadmin/{private,public}/conf/gitolite.conf

cat > /tmp/gitolite.conf << EOF
repo  gitolite-admin
RW+ = gitadmin unforgiven512

repo  testing
RW+ = gitadmin unforgiven512
R   = @all
EOF

cp /tmp/gitolite.conf /home/gitadmin/private/conf/gitolite.conf
cp /tmp/gitolite.conf /home/gitadmin/public/conf/gitolite.conf
chown gitadmin:gitadmin /home/gitadmin/{private,public}/conf/gitolite.conf

# commit changes
su - gitadmin -c "cd /home/gitadmin/private && git add * && git commit -m 'initial setup by gitsetup.sh' && git push origin master"
su - gitadmin -c "cd /home/gitadmin/public && git add * && git commit -m 'initial setup by gitsetup.sh' && git push origin master"

# inform user that they can now clone the gitadmin repositories from their client pc
echo "You may now check out the gitolite-admin repositories on your local computer."
echo "Public: git clone git@$HOSTNAME_FQDN:gitolite-admin ~/public"
echo "Private: git clone team@$HOSTNAME_FQDN:gitolite-admin ~/private"

## GITWEB ##

# setup users for gitweb hosting
mkdir -p /var/log/www/{git,team}
#chown git:www-data /srv/git/public
chown root:git /var/log/www/git
#chown team:www-data /srv/git/private
chown root:team /var/log/www/team

su - git -c "ln -s /var/log/www/git /home/git/logs"
su - team -c "ln -s /var/log/www/team /home/team/logs"

# make gitweb.cgi "wrapper" scripts
mkdir -p /var/www/fcgi-bin.d/{gitweb-git,gitweb-team}

cat > /tmp/gitweb-fcgi-wrapper << EOF
#!/bin/sh
# Wrapper for gitweb.cgi
exec /usr/lib/cgi-bin/gitweb.cgi
EOF

cp /tmp/gitweb-fcgi-wrapper /var/www/fcgi-bin.d/gitweb-git/
cp /tmp/gitweb-fcgi-wrapper /var/www/fcgi-bin.d/gitweb-team/

chown -R git:git /var/www/fcgi-bin.d/gitweb-git
chown -R team:team /var/www/fcgi-bin.d/gitweb-team
chmod u+x /var/www/fcgi-bin.d/gitweb-git/gitweb-fcgi-wrapper
chmod u+x /var/www/fcgi-bin.d/gitweb-team/gitweb-fcgi-wrapper

# copy config files to each user's homedir
cp /etc/gitweb.conf /home/git/gitweb.conf
cp /etc/gitweb.conf /home/team/gitweb.conf

# change projectroot in each
sed -i 's/\$projectroot = \"\/var\/cache\/git\";/\$projectroot = \"\/srv\/git\/private\";/' /home/team/gitweb.conf
sed -i 's/\$projectroot = \"\/var\/cache\/git\";/\$projectroot = \"\/srv\/git\/public\";/' /home/git/gitweb.conf

# FIXME: edit more stuff in gitweb.conf

# FIXME: setup vhosts, etc
