
-- YYYYmmddHHMM
-- 201804092200 up
-- http://www.sqlite.org/pragma.html#pragma_encoding
PRAGMA encoding = "UTF-8";
PRAGMA temp_store = MEMORY;
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
  -- 'last modification time'
  -- 'All dates are stored as seconds since the epoch(1970) in GMT.
  -- In Perl we use gmtime as object from Time::Piece'
  tstamp INTEGER DEFAULT 0,
  -- 'registration time',,
  reg_time INTEGER DEFAULT 0,
  disabled INT(1) DEFAULT 1,
  start_date INTEGER DEFAULT 0,
  stop_date INTEGER DEFAULT 0
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

-- YYYYmmddHHMM
-- 201804302200 up
-- 'Sites managed by this system'
CREATE TABLE domove (
-- domove is the plural form of 'dom' in Bulgarian, meaning 'home'.
-- The similarity with domains is not a coincidence
--  'Id referenced by stranici that belong to this domain.'
  id INTEGER PRIMARY KEY AUTOINCREMENT,
--  'Domain name as in $ENV{HTTP_HOST}.'
  domain VARCHAR(63) UNIQUE NOT NULL,
--  'The name of this site.'
  site_name VARCHAR(63) NOT NULL,
--  'Site description'
  description VARCHAR(2000) NOT NULL DEFAULT '',
--   'User for which the permissions apply (owner).'
  owner_id INTEGER REFERENCES users(id),
--  'Group for which the permissions apply.'
  group_id INTEGER  REFERENCES groups(id),
--  'Domain permissions',
  permissions VARCHAR(10) DEFAULT '-rwxr-xr-x' ,
--  '0:not published, 1:for review, >=2:published'
  published INT(1) DEFAULT 0
);

CREATE INDEX IF NOT EXISTS domove_published ON domove(published);

INSERT INTO domove (id, domain, description, site_name, owner_id, permissions, published)
    VALUES ( 0, 'localhost', 'default domain', 'Слово', 0, '-rwxr-xr-x', 2);

CREATE TABLE stranici (
  -- 'stranica(страница)' in Bulgarian means 'page'.
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- Parent page id
  pid INTEGER DEFAULT 0,
  -- Refrerence to domove.id to which this page belongs.
  dom_id INTEGER DEFAULT 0,
  -- Alias for the page which may be used instead of the id.
  alias VARCHAR(32) NOT NULL,
  -- 'обичайна','коренъ' etc.
  page_type VARCHAR(32) NOT NULL,
  -- Page editing permissions. Prefixes: d - folder, l - link
  permissions varchar(10) DEFAULT '-rwxr-xr-x',
  sorting INTEGER DEFAULT 1,
  -- MT code to display this page. Default template is used if not specified.
  template VARCHAR(255),
  -- User for which the permissions apply (owner/creator).
  user_id INTEGER,
  -- Group for which the permissions apply (usually primary group of the owner).
  group_id INTEGER,
  tstamp INTEGER DEFAULT 0,
  start INTEGER DEFAULT 0,
  stop INTEGER DEFAULT 0,
  -- 0: not published, 1: for review/preview, >=2: published
  published int(1) DEFAULT 1,
  -- Is this page hidden? 0=No, 1=Yes
  hidden int(1) DEFAULT 0,
  -- Is this page deleted? 0=No, 1=Yes
  deleted int(1) DEFAULT 0,
  -- Who modified this page the last time?
  changed_by INTEFER REFERENCES users(id),
  FOREIGN KEY (pid)       REFERENCES stranici(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (dom_id)    REFERENCES domove(id)   ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (user_id)   REFERENCES users(id)    ON UPDATE CASCADE,
  FOREIGN KEY (group_id)  REFERENCES groups(id)   ON UPDATE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS stranici_alias_in_domove ON stranici(alias, dom_id);
CREATE INDEX IF NOT EXISTS stranici_user_id_group_id ON stranici(user_id, group_id);
CREATE INDEX IF NOT EXISTS stranici_hidden ON stranici(hidden);

-- only root pages have pid same as id!
INSERT INTO stranici (
    id, alias, changed_by, deleted, dom_id, group_id, hidden, page_type,
    permissions, pid, published, sorting, start, stop, tstamp, user_id)
VALUES (
    0, 'коренъ', 0, 0, 0, 0, 0, 'root',
    '-rwxr-xr-x', 0, 1, 0, 0, 0, 1523795424, 0);


 -- Initially created by SQL::Translator::Producer::SQLite
 -- Created on Sat Apr 14 13:32:46 2018
 --

 CREATE TABLE celini (
 -- content elements are one or more paragraphs, or whole article. Different
 -- data_types denote the semantic of a content element.
 -- This table is a modified version of MYDLjE table "content".
 -- 'celina(цѣлина)' is the original Bulgarian word for 'paragraph'.

  -- Primary unique identifier
  id INTEGER PRIMARY KEY,
  -- Lowercased and trimmed of \W characters unique identifier for the row data_type
  alias VARCHAR(255) DEFAULT 'seo-friendly-id',
  -- Parent content: Question, Article, Note, Book ID etc.
  pid INTEGER DEFAULT 0,
  -- Id from which this content is copied (translated), if not original content.
  from_id INTEGER DEFAULT 0,
  -- page.id to which this content belongs. Default: 0
  page_id INTEGER DEFAULT 0,
  -- User for which the permissions apply (owner).
  user_id INTEGER NOT NULL,
  -- Group for which the permissions apply.(primary group of the user by default)
  group_id INTEGER NOT NULL,
  -- For sorting chapters in a book, stranici in a menu etc.
  sorting int(10) DEFAULT 0,
  -- Semantic content types. 'въпросъ', 'ѿговоръ', 'писанѥ', 'белѣжка', 'книга', 'заглавѥ', 'цѣлина'…
  data_type VARCHAR(32) DEFAULT 'белѣжка',
  -- text, html, markdown, asc…
  data_format VARCHAR(32) DEFAULT 'text',
  -- When this content was inserted
  created_at INTEGER NOT NULL DEFAULT 0,
  -- Last time the record was touched
  tstamp INTEGER DEFAULT 0,
  -- Used in title html tag for stranici or or as h1 for other data types.
  title VARCHAR(255) DEFAULT '',
  -- Used in description meta tag when appropriate.
  description VARCHAR(255) DEFAULT '',
  -- Used in keywords meta tag.
  keywords VARCHAR(255) DEFAULT '',
  -- Used in tag cloud boxes. merged with keywords and added to keywords meta tag.
  tags VARCHAR(100) DEFAULT '',
  -- Main celini when applicable.
  body TEXT DEFAULT '',
  -- celini box in which this element should be displayed (e.g. main|главна, left|лѣва, right|дѣсна, header|глава, footer|дъно, foo, bar).
  box VARCHAR(35) DEFAULT 'main',
  -- Language of this content. All languages when empty string
  language VARCHAR(5) DEFAULT '',
  -- tuuugggooo - Experimental permissions for the content. Who can see/edit/delete it.
  -- TODO: document and design the behavior for pages which are "d" (directories) and "l" (links)
  permissions char(10) DEFAULT '-rwxr-xr-x',
  -- Show on top independently of other sorting.
  featured int(1) DEFAULT 0,
  -- Answer accepted?
  accepted int(1) DEFAULT 0,
  -- Reported as inapropriate offensive etc. higher values -very bad.
  bad int(2) DEFAULT 0,
  -- When set to 1 the record is not visible anywhere.
  deleted int(1) DEFAULT 0,
  -- Date/Time from which the record will be accessible in the site.
  start INTEGER DEFAULT 0,
  -- Date/Time till which the record will be accessible in the site.
  stop INTEGER DEFAULT 0,
  -- Who modified this цѣлина the last time?
  changed_by INTEFER REFERENCES users(id),
  FOREIGN KEY (pid)      REFERENCES celini(id)   ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (page_id)  REFERENCES stranici(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (user_id)  REFERENCES users(id)    ON UPDATE CASCADE,
  FOREIGN KEY (group_id) REFERENCES groups(id)   ON UPDATE CASCADE
 );

 CREATE INDEX celini_pid ON celini (pid);
 CREATE INDEX celini_tags ON celini (tags);
 CREATE INDEX celini_user_id_group_id ON celini (user_id, group_id);
 CREATE INDEX celini_data_type ON celini (data_type);
 CREATE INDEX celini_language ON celini (language);
 CREATE INDEX celini_page_id ON celini (page_id);
 CREATE INDEX celini_deleted ON celini (deleted);
 CREATE UNIQUE INDEX celini_alias_with_data_type_in_page_id ON celini (alias, data_type, page_id);

 CREATE INDEX user_group_id ON users(group_id);

  INSERT INTO celini (
      id, alias, body, created_at, data_format, data_type, group_id,
      keywords, language, page_id, pid, tags, title, user_id)
  VALUES (
      0, 'начало', '', 1523807733, 'text', 'заглавѥ', 0,
      'Slovo, Слово', 'bg', 0, 0, 'начало, home', 'Слово', 0);


-- 201804302200 down
DROP TABLE IF EXISTS domove;
DROP TABLE IF EXISTS stranici;
DROP TABLE IF EXISTS celini;

-- 201805012200 up
UPDATE stranici SET alias = 'коренъ',"page_type" = 'коренъ',
permissions = 'drwxr-xr-x' WHERE ( id = 0 );
INSERT INTO stranici VALUES(1,0,0,'писания','обичайна','drwxr-xr-x',1,NULL,5,5,1525187608,1525187608,0,1,0,0,NULL);
INSERT INTO stranici VALUES(2,1,0,'вести','обичайна','-rwxr-xr-x',1,NULL,5,5,1525191489,1525191489,0,1,0,0,NULL);
INSERT INTO stranici VALUES(3,0,0,'ѿносно','обичайна','-rwxr-xr-x',1,NULL,5,5,1525193683,1525193683,0,1,0,0,NULL);

UPDATE "celini" SET "body" = 'Добре дошли на страниците на слово.бг!',
"language" = 'bg-bg', "title" = 'Слово' WHERE ( "id" = 0 );
INSERT INTO "celini"
VALUES(1,'писания',0,0,1,5,5,0,'заглавѥ','text',1525178911,0,'Писания',
    '','','','Добре дошли на нашата страница за „Писания“! Опитайте и вие да
    напишете нещо, може да ви се удаде. Ура, записва!','main','bg-bg',
    '-rwxr-xr-x',0,0,0,0,0,0,5);
INSERT INTO "celini"
VALUES(3,'вести',0,0,2,5,5,0,'заглавѥ','text',1525191489,0,'Вести','',
    '','','Новините са в този раздел.','main','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,5);
INSERT INTO "celini"
VALUES(4,'ѿносно',0,0,3,5,5,0,'заглавѥ','text',1525193683,0,'Ѿносно',
    '','','','Обяснения за сайта. Какъв е и за какво се говори в него. Каква е
    неговата цел.','main','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,5);

-- 201805012200 down
delete from stranici where id >0;


-- 201805242200 up
UPDATE stranici set group_id=5 where alias='коренъ';
INSERT INTO "stranici" VALUES(4, 0, 0, 'не-е-намерена', 'обичайна', 'drwxr-xr-x', 1, NULL, 5, 5, 1527802409, 1527802409, 0, 1, 0, 0, NULL);

INSERT INTO "celini" VALUES(5,'втора-цѣлина',0,0,0,5,5,1,'цѣлина', 'html', 1526844885, 0, 'Втора цѣлина', '', '', '', 'нещо още в главната кутия на страницата','главна','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,5);
INSERT INTO "celini" VALUES(6,'северна-и-южна-корея-в-спор-за-12-сервитьорки',0,0,0,5,5,2, 'цѣлина', 'html' , 1526851706, 0,'Северна и Южна Корея в спор за 12 сервитьорки','','','','<p>Северна Корея настоя Южна Корея да върне обратно 12 сервитьорки,
    за които твърди, че са отвлечени, предава AFP.</p>
<p>Те са работели в държавен севернокорейски ресторант в Китай. Управителят на ресторанта казва, че ги излъгал и принудил да го  последват по нареждане на южнокорейските тайни служби.</p>
<p>„Южнокорейските власти трябва незабавно да върнат нашите гражданки обратно при семействата им и това ще покаже воля за подобряване на двустранните отношения“, заявяват от Пхенян.</p>
<p>Сеул настоява, че те са избягали в страната преди около две години и са останали в нея по собствено желание.</p>','главна','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,5);
INSERT INTO "celini" VALUES(7,'меню-незадължително',0,0,0,5,5,0,'заглавѥ','text',1527027334,0,'меню незадължително','','','','<ul>
<li>Първо</li><li>Второ</li>
<li>Трето
  <ul><li>Първо</li><li>Второ</li></ul>
</li>
<li>Четвърто</li>
</ul>','лѣво','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,5);

INSERT INTO "celini" VALUES(8,'реклама',0,0,0,5,5,0,'заглавѥ','text',1527027663,0,'Реклама','','','','<div style="height:12em;background:red"> text here</div>
<div style="height:12em;background:blue">image and text</div>','дѣсно','bg-bg','-rwxr-xr-x',0,0,0,0,3,1558563642,5);
INSERT INTO "celini" VALUES(9,'страницата-не-е-намерена',0,0,4,5,5,0,'заглавѥ','text',1527802409,0,'Страницата не е намерена',
    '','','','Страницата, която търсите не бе намерена.','main','bg-bg','-rwxr-xr-x',0,0,0,0,0,0,NULL);

-- add user краси to group test1 for testing page displaying
INSERT INTO user_group VALUES(5,3);
UPDATE stranici set user_id=3, group_id=3 WHERE alias='вести';

-- 201805242200 down
DELETE FROM celini WHERE id in (5,6,7,8,9);
DELETE FROM user_group WHERE user_id=5 AND group_id=3;
UPDATE stranici set user_id=5, group_id=3 WHERE alias='вести';

-- 201806062200 up


UPDATE stranici set published=2 WHERE alias IN('коренъ', 'не-е-намерена');

INSERT INTO "stranici" VALUES(5, 0, 0, 'скрита', 'обичайна', 'drwxr-xr-x', 111,
    NULL, 5, 5, 1527963618, 1527962484, 0, 2, 1, 0, NULL);

INSERT INTO "stranici" VALUES(6, 0, 0, 'изтрита', 'обичайна', 'drwxr-xr-x', 1,
    NULL, 5, 5, 1527964061, 1527964061, 0, 1, 0, 1, NULL);

INSERT INTO "stranici" VALUES(7, 0, 0, 'изтекла', 'обичайна', 'drwxr-xr-x', 1,
    NULL, 5, 5, 1527964237, 1527964237, 1527963618, 2, 0, 0, NULL);

INSERT INTO "stranici" VALUES(8, 0, 0, 'предстояща', 'обичайна', 'drwxr-xr-x',
    1, NULL, 5, 5, 1527965753, 5527963618, 0, 2, 0, 0, NULL);

INSERT INTO "celini" VALUES(10, 'скрита', 0, 0, 5, 5, 5, 0, 'заглавѥ', 'text',
    1527963618, 0, 'Скрита страница', '', '', '', 'Една скрита страница.',
    'main', 'bg-bg', '-rwxr-xr-x', 0, 0, 0, 0, 0, 0, NULL);

INSERT INTO "celini" VALUES(11, 'изтрита', 0, 0, 6, 5, 5, 0, 'заглавѥ', 'text',
    1527964061, 0, 'Изтрита страница', '', '', '', 'Една изтрита страница.',
    'main', 'bg-bg', '-rwxr-xr-x', 0, 0, 0, 0, 0, 0, NULL);

INSERT INTO "celini" VALUES(12, 'изтекла', 0, 0, 7, 5, 5, 0, 'заглавѥ', 'text',
    1527964237, 0, 'Изтекла страница', '', '', '', 'Една изтекла страница.',
    'main', 'bg-bg', '-rwxr-xr-x', 0, 0, 0, 0, 0, 0, NULL);

INSERT INTO "celini" VALUES(13, 'предстояща', 0, 0, 8, 5, 5, 0, 'заглавѥ',
    'text', 1527965753, 0, 'Предстояща', '', '', '', 'Страница, която ще
    започне да се показва след определено време.', 'main', 'bg-bg',
    '-rwxr-xr-x', 0, 0, 0, 0, 0, 0, NULL);

ALTER TABLE celini ADD COLUMN published INT(1) DEFAULT 0;
-- Synchronise 'published' status of content with their pages
UPDATE celini SET published=(SELECT published FROM stranici WHERE id=celini.page_id);

-- IPs from which this domain may be served, eg localhost can be on '127.0.0.1,127.0.1.1'
ALTER TABLE domove ADD COLUMN ips VARCHAR DEFAULT '127.0.0.1,127.0.1.1';
CREATE INDEX domove_ips ON domove(ips);

-- 201806062200 down
UPDATE stranici set published=1 WHERE alias='коренъ';
DELETE FROM stranici WHERE id in (5,6,7,8);
-- No need to delete from celini as they will cascade.
-- NO "DROP COLUMN" in SQLite so we will not do the usual workaround with
-- recreating the table.table

-- 201806252200 up
UPDATE stranici set published=2 WHERE alias='ѿносно';
-- Synchronise 'published' status of content with their pages
UPDATE celini SET published=2 where page_id=(SELECT id FROM stranici WHERE alias='ѿносно');
-- update an article from the home page with more meanigful text.
UPDATE celini SET title='Ползата от историята', body='<p><img
src="http://www.pravoslavieto.com/books/history_paisij/history_Paisij.jpg"
alt="&quot;История славяноболгарская&quot; св. Паисий Хилендарски" width="300"
hspace="6" height="483" align="right">Да се познават случилите се по-рано в тоя
свят неща и делата на ония, които са живеели на земята, е не само полезно, но и
твърде потребно, любомъдри читателю. Ако навикнеш да прочиташ често тия неща,
ще се обогатиш с разум, не ще бъдеш много неизкусен и ще отговаряш на малките
деца и простите хора, когато при случай те запитат за станалите по-рано в света
деяния от черковната и гражданска история. И не по-малко ще се срамуваш, когато
не можеш да отговориш за тях.</p>

<p>Отгде ще можеш да добиеш тия знания, ако не от ония, които писаха историята
на този свят и които при все че не са живели дълго време, защото никому не се
дарява дълъг живот, за дълго време оставиха писания за тия неща. Сами от себе
си да се научим не можем, защото кратки са дните на нашия живот на земята.
Затова с четене на старите летописи и с чуждото умение трябва да попълним
недостатъчността на нашите години за обогатяване на разума.</p>

<p>Искаш ли да седиш у дома си и да узнаеш без много трудно и опасно пътуване
миналото на всички царства на тоя свят и ставащите сега събития в тях и да
употребиш тия знания за умна наслада и полза за себе си и за другите, чети
историята! Искаш ли да видиш като на театър играта на тоя свят, промяната и
гибелта на големи царства и царе и непостоянството на тяхното благополучие, как
господстващите и гордеещите се между народите племена, силни и непобедими в
битките, славни и почитани от всички, внезапно отслабваха, смиряваха се,
упадаха, загиваха, изчезваха - чети историята и като познаеш от нея суетата на
този свят, научи се да го презираш. Историята дава разум не само на всеки
човек, за да управлява себе си или своя дом, но и на големите владетели за
добро властвуване: как могат да държат дадените им от бога поданици в страх
божи, в послушание, тишина, правда и благочестие, как да укротяват и
изкореняват бунтовниците, как да се опълчват против външните врагове във
войните, как да ги победят и сключат мир. Виж колко голяма е ползата от
историята. Накратко това е заявил Василий, источният кесар, на своя син Лъв
Премъдри. Съветайки го, каза: „Не преставай - рече - да четеш историята на
древните. Защото там без труд ще намериш онова, за което други много са се
трудили. От тях ще узнаеш добродетелите на добрите и законопрестъпленията на
злите, ще познаеш превратностите на човешкия живот и обратите на благополучието
в него, и непостоянството в този свят, и как и велики държави клонят към
падение. Ще размислииш и ще видиш наказанието на злите и наградата на добрите.
От тях се пази!”</p>' WHERE id=6;

-- 201806252200 down
UPDATE stranici set published=1 WHERE alias='ѿносно';
-- Synchronise 'published' status of content with their pages
UPDATE celini SET published=1 where page_id=(SELECT id FROM stranici WHERE alias='ѿносно');

-- 201807202200 up
UPDATE "celini" SET
    "alias" = "първа-лѣва-кутия", "data_type" = "цѣлина",
    "body" = "Първа лѣва обнародвана кутийка с нѣкакъв текст в лѣвия панел.",
    "published" = 2, "sorting" = 1, "title" = "Първа лѣва кутия "
    WHERE ( "id" = 7 );

UPDATE "stranici" SET
    "permissions" = "drwxrwxr-x", "published" = 2
    WHERE ( "id" IN (1,2) );
UPDATE "celini" SET "published" = 2 WHERE (page_id IN (1,2) );
-- 201807201100 down

-- 201807281100 up
ALTER TABLE domove ADD COLUMN aliases VARCHAR(2000);
-- 201807282200 down
-- no downgrade path for this version


