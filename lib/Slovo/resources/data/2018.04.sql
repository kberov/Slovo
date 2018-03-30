-- YYYYmmddHHMM
-- 201804000000 up
/**
 Careful developers will not make any assumptions about whether or not
 foreign keys are enabled by default but will instead enable or disable
 them as necessary.
 http://www.sqlite.org/foreignkeys.html#fk_enable
 http://www.sqlite.org/pragma.html
*/
PRAGMA encoding = "UTF-8"; 
PRAGMA foreign_keys = OFF;

-- 'Groups for users in a Слово system.'
CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(100) UNIQUE NOT NULL,
  description VARCHAR(255) NOT NULL,
--  'id of who created this group.'
  created_by INTEGER REFERENCES users(id),
--  'id of who changed this group.'
  changed_by INTEGER REFERENCES users(id), 
  disabled INT(1) NOT NULL DEFAULT 1
);

-- 'This table stores the users'
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
--  'Primary group for this user'
  group_id INTEGER REFERENCES groups(id),
  login_name varchar(100) UNIQUE,
--  'Mojo::Util::sha1_hex($login_name.$login_password)'
  login_password varchar(40) NOT NULL,
  first_name varchar(100) NOT NULL DEFAULT '',
  last_name varchar(100) NOT NULL DEFAULT '',
  email varchar(255) NOT NULL UNIQUE,
  description varchar(255) DEFAULT NULL,
--  'id of who created this user.'
  created_by INTEGER REFERENCES users(id),
--  'Who modified this user the last time?'
  changed_by INTEGER REFERENCES users(id), 
--  'last modification time'
--  'All dates are stored as seconds since the epoch(1970) in GMT. In Perl we use gmtime as object from Time::Piece'
  tstamp INTEGER NOT NULL DEFAULT 0,
--  'registration time',,
  reg_time INTEGER NOT NULL DEFAULT 0, 
  disabled INT(1) NOT NULL DEFAULT 1,
  start_date INTEGER NOT NULL DEFAULT 0,
  stop_date INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX user_start_date ON users(start_date);
CREATE INDEX user_stop_date ON users(stop_date);


-- 'Which user to which group belongs'
CREATE TABLE IF NOT EXISTS user_group (
--  'ID of the user belonging to the group with group_id.'
  user_id INTEGER  REFERENCES users(id),
--  'ID of the group to which the user with user_id belongs.'
  group_id INTEGER  REFERENCES groups(id),
  PRIMARY KEY(user_id, group_id)
);

INSERT INTO `groups` VALUES(0,'null','null group',1,1,1);
INSERT INTO `users` VALUES(0,0,'null','9f1bd12057905cf4f61a14e3eeac06bf68a28e64',
'Null','Null','null@localhost',
'System user. Do not use!',
1,1,54022241011303270,0,1,1,1);

INSERT INTO `groups` VALUES(1,'admin','admin',1,1,0);
INSERT INTO `users` VALUES(1,1,'foo','9f1bd12057905cf4f61a14e3eeac06bf68a28e64',
'Foo','Bar','foo@localhost',
'System user. Do not use!',
1,1,54022241011303270,0,1,0,0);
INSERT INTO `user_group` VALUES(1,1);

INSERT INTO `groups` VALUES(2,'guest','guest',1,1,0);
INSERT INTO `users` VALUES(2,2,'guest','8097beb8d5950479e49d803e683932150f469827',
'Guest','','guest@localhost',
'Guest user. Anybody not authenticated is a guest user.',
1,1,54022241011303270,0,1,0,0);
INSERT INTO `user_group` VALUES(2,2);

INSERT INTO `groups` VALUES(3,'test1','test1',1,1,0);
INSERT INTO `users` VALUES(3,3,'test1','b5e9c9ab4f777c191bc847e1aca222d6836714b7',
'Test','1','test1@localhost',
'test1 user. Do not delete. used for tests only.',
1,1,1911303270,0,0,0,0);
INSERT INTO `user_group` VALUES(3,3);

INSERT INTO `groups` VALUES(4,'test2','test2',1,1,0);
INSERT INTO `users` VALUES(4,4,'test2','272a11a0206b949355be4b0bda9a8918609f1ac6',
'Test','2','test2@localhost',
'test2 user. Do not delete. Used for tests only.',
1,1,1911303270,0,0,0,0);
INSERT INTO `user_group` VALUES(4,4);


-- 201804000000 down
DROP TABLE IF EXISTS user_group;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS groups;

