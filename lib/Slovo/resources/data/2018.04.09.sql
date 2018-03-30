-- YYYYmmddHHMM
-- 201804092200 up

-- 'Groups for users in a Слово system.'
CREATE TABLE groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(100) UNIQUE NOT NULL,
  description VARCHAR(255) NOT NULL,
  disabled INT(1) NOT NULL DEFAULT 1
);

-- 'This table stores the users'
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  login_name varchar(100) UNIQUE,
-- sha1_sum($login_name.$login_password)
login_password varchar(40) NOT NULL,
  first_name varchar(100) NOT NULL DEFAULT '',
  last_name varchar(100) NOT NULL DEFAULT '',
  email varchar(255) NOT NULL UNIQUE,
  description varchar(255) DEFAULT NULL,
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
CREATE TABLE user_group (
--  'ID of the user belonging to the group with group_id.'
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
--  'ID of the group to which the user with user_id belongs.'
  group_id INTEGER REFERENCES groups(id) ON DELETE CASCADE,
  PRIMARY KEY(user_id, group_id)
);

INSERT INTO `groups`(id,name,description) VALUES(0,'null','null group');
INSERT INTO `users` (id,login_name,login_password,first_name,last_name,email,description) 
    VALUES(0,'null','9f1bd12057905cf4f61a14e3eeac06bf68a28e64',
    'Null','Null','null@localhost','Disabled system user. Do not use!');
INSERT INTO `user_group` VALUES(0,0);


-- Why we add columns(constraints) later? See https://stackoverflow.com/questions/1884818/#23574053
ALTER TABLE groups ADD COLUMN created_by INTEGER DEFAULT NULL REFERENCES users(id) ON DELETE SET DEFAULT;
ALTER TABLE groups ADD COLUMN changed_by INTEGER DEFAULT NULL REFERENCES users(id) ON DELETE SET DEFAULT;

ALTER TABLE users ADD COLUMN group_id INTEGER DEFAULT NULL REFERENCES groups(id) ON DELETE SET DEFAULT;
ALTER TABLE users ADD COLUMN created_by INTEGER DEFAULT NULL REFERENCES users(id) ON DELETE SET DEFAULT;
ALTER TABLE users ADD COLUMN changed_by INTEGER DEFAULT NULL REFERENCES users(id) ON DELETE SET DEFAULT;

INSERT INTO groups VALUES(1,'admin','group for administrators',0,0,0);
INSERT INTO users VALUES(1,'foo','9f1bd12057905cf4f61a14e3eeac06bf68a28e64','Foo','Bar','foo@localhost',
  'System user. Do not use!',1,1,0,0,0, 1,0,0);
 INSERT INTO `user_group` VALUES(1,1);
 
INSERT INTO groups VALUES(2,'guest','guest',0,1,1);
INSERT INTO users
VALUES(2,'guest','8097beb8d5950479e49d803e683932150f469827','гостенин','','guest@localhost',
  'Guest user. Anybody not authenticated is a guest user.',
  1,1,0,0,0, 2,1,1);
INSERT INTO `user_group` VALUES(2,2);
 
INSERT INTO `groups` VALUES(3,'test1','test1',1,1,1);
INSERT INTO `users` VALUES(3,'test1','b5e9c9ab4f777c191bc847e1aca222d6836714b7','Test','1','test1@localhost',
  'test1 user. Delete. used for tests only.',1,1,1,0,0, 3,1,1);
INSERT INTO `user_group` VALUES(3,3);
 
INSERT INTO `groups` VALUES(4,'test2','test2',0,1,1);
INSERT INTO `users` VALUES(4,'test2','272a11a0206b949355be4b0bda9a8918609f1ac6','Test','2','test2@localhost',
  'test2 user. Delete. Used for tests only.',
  1,1,0,0,0, 4,1,1); 
INSERT INTO `user_group` VALUES(4,4);

INSERT INTO `groups` VALUES(5,'краси','краси',0,4,4);
-- sha1_sum(encode("utf8","красиберов")
INSERT INTO `users` VALUES(5,'краси','f65676423e87854b434b8015da176c01b086ef0b','Краси','Беров','краси@localhost',
    'краси user. Delete this user. ' || 'Used for tests only.',1,1,0,0,0, 5,4,4);
INSERT INTO `user_group` VALUES(5,5);

-- 201804092200 down
DROP TABLE IF EXISTS user_group;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS groups;

