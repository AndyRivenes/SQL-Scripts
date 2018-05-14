--  FILE:   lockmon.sql
--
--  AUTHOR: Andy Rivenes, arivenes@appsdba.com, www.appsdba.com
--          Copyright (c) 1996-2006, AppsDBA Consulting. All Rights Reserved.
--
--  DATE:   05/03/96
--
--  DESCRIPTION:
--          Query to display all current database locks.
--          
--  REQUIREMENTS:
--          Must be Version 7.3 or greater.
--
--  MODIFICATIONS:
--          N. Jensen, unknown,   I think Neil added all the fancy
--                                formatting.
--          A. Rivenes, 11/05/96, Changed the join on v$session and
--                                v$process to use addr and paddr rather
--                                than pid and sid.
--                                This is needed to handle MTS connections.
--          A. Rivenes, 12/27/96, Changed the way username and OS PID 
--                                were used and changed the background process 
--                                detection to use V$SESSION instead of V$PROCESS.
--                                This query now matches the output of OEM Top Sessions.
--          A. Rivenes, 11/05/98, Added all commands to the command decode.
--          A. Rivenes, 03/26/99, Added convert time and blocking information from V$LOCK.
--                                This now makes this query restricted to 7.3+.
--          A. Rivenes, 09/10/99, Updated the handling of waiting transactions to be
--                                more informative, removed addresses.
--          A. Rivenes, 10/06/99, Changed the UNION to a UNION ALL, fixed the RULE mode,
--                                the optimizer ignores hints for queries with a UNION so
--                                an alter session command is now used.
--          A. Rivenes, 11/29/00, Changed the mapping from v$resource to sys.obj$ to an outer
--                                join.  Suspect that a resource does not have to map to an
--                                object.
--          A. Rivenes, 04/06/04, Added block and row being locked from v$session.
--          A. Rivenes, 11/01/06, Removed unneeded reference to v$resource.
--
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- 
--
SET LINESIZE 132;
SET PAGESIZE 60;
--
COLUMN username    HEADING 'ORACLE|User'     FORMAT A7      TRUNCATE;
COLUMN sid         HEADING 'SID'             FORMAT 9999;
COLUMN command     HEADING 'SQL|Command'     FORMAT A10     WORD_WRAPPED;
COLUMN ltype       HEADING 'Lock|Type'       FORMAT A11     WORD_WRAPPED;
COLUMN lmode       HEADING 'Mode|Held'       FORMAT A10     WORD_WRAPPED;
COLUMN request     HEADING 'Mode|Request'    FORMAT A10     WORD_WRAPPED;
COLUMN ctime       HEADING 'Last|Cnvrt|Time' FORMAT 999999;
COLUMN blkothr     HEADING 'Blocking'        FORMAT A8;
COLUMN owner       HEADING 'Owner'           FORMAT A8      TRUNCATE;
COLUMN image       HEADING 'Object'          FORMAT A20     TRUNCATE;
COLUMN lblock      HEADING 'Block'           FORMAT A8;
COLUMN lrow        HEADING 'Row'             FORMAT A8;
--
SELECT se.username,
       se.sid,
       DECODE( se.command,
               0, 'No command',
               1, 'CREATE TABLE',
               2, 'INSERT',
               3, 'SELECT',
               4, 'CREATE CLUSTER',
               5, 'ALTER CLUSTER',
               6, 'UPDATE',
               7, 'DELETE',
               8, 'DROP CLUSTER',
               9, 'CREATE INDEX',
               10, 'DROP INDEX',
               11, 'ALTER INDEX',
               12, 'DROP TABLE',
               13, 'CREATE SEQUENCE',
               14, 'ALTER SEQUENCE',
               15, 'ALTER TABLE',
               16, 'DROP SEQUENCE',
               17, 'GRANT',
               18, 'REVOKE',
               19, 'CREATE SYNONYM',
               20, 'DROP SYNONYM',
               21, 'CREATE VIEW',
               22, 'DROP VIEW',
               23, 'VALIDATE INDEX',
               24, 'CREATE PROCEDURE',
               25, 'ALTER PROCEDURE',
               26, 'LOCK TABLE',
               27, 'NO OPERATION',
               28, 'RENAME',
               29, 'COMMENT',
               30, 'AUDIT',
               31, 'NOAUDIT',
               32, 'CREATE DATABASE LINK',
               33, 'DROP DATABASE LINK',
               34, 'CREATE DATABASE',
               35, 'ALTER DATABASE',
               36, 'CREATE ROLLBACK SEGMENT',
               37, 'ALTER ROLLBACK SEGMENT',
               38, 'DROP ROLLBACK SEGMENT',
               39, 'CREATE TABLESPACE',
               40, 'ALTER TABLESPACE',
               41, 'DROP TABLESPACE',
               42, 'ALTER SESSION',
               43, 'ALTER USER',
               44, 'COMMIT',
               45, 'ROLLBACK',
               46, 'SAVEPOINT',
               47, 'PL/SQL EXECUTE',
               48, 'SET TRANSACTION', 
               49, 'ALTER SYSTEM SWITCH LOG',
               50, 'EXPLAIN',
               51, 'CREATE USER',
               52, 'CREATE ROLE',
               53, 'DROP USER',
               54, 'DROP ROLE',
               55, 'SET ROLE',
               56, 'CREATE SCHEMA',
               57, 'CREATE CONTROL FILE',
               58, 'ALTER TRACING',
               59, 'CREATE TRIGGER',
               60, 'ALTER TRIGGER',
               61, 'DROP TRIGGER',
               62, 'ANALYZE TABLE',
               63, 'ANALYZE INDEX',
               64, 'ANALYZE CLUSTER',
               65, 'CREATE PROFILE',
               67, 'DROP PROFILE',
               68, 'ALTER PROFILE',
               69, 'DROP PROCEDURE',
               70, 'ALTER RESOURCE COST',
               71, 'CREATE SNAPSHOT LOG',
               72, 'ALTER SNAPSHOT LOG',
               73, 'DROP SNAPSHOT LOG',
               74, 'CREATE SNAPSHOT',
               75, 'ALTER SNAPSHOT',
               76, 'DROP SNAPSHOT',
               79, 'ALTER ROLE',
               85, 'TRUNCATE TABLE',
               86, 'TRUNCATE CLUSTER',
               88, 'ALTER VIEW',
               91, 'CREATE FUNCTION',
               92, 'ALTER FUNCTION',
               93, 'DROP FUNCTION',
               94, 'CREATE PACKAGE',
               95, 'ALTER PACKAGE',
               96, 'DROP PACKAGE',
               97, 'CREATE PACKAGE BODY',
               98, 'ALTER PACKAGE BODY',
               99, 'DROP PACKAGE BODY',
         TO_CHAR(se.command) ) command,
       DECODE(lo.type,
         'MR', 'Media Recovery',
         'RT', 'Redo Thread',
         'UN', 'User Name',
         'TX', 'Transaction',
         'TM', 'DML',
         'UL', 'PL/SQL User Lock',
         'DX', 'Distributed Xaction',
         'CF', 'Control File',
         'IS', 'Instance State',
         'FS', 'File Set',
         'IR', 'Instance Recovery',
         'ST', 'Disk Space Transaction',
         'TS', 'Temp Segment',
         'IV', 'Library Cache Invalidation',
         'LS', 'Log Start or Switch',
         'RW', 'Row Wait',
         'SQ', 'Sequence Number',
         'TE', 'Extend Table',
         'TT', 'Temp Table',
         'JQ', 'Job Queue',
         lo.type) ltype,
       DECODE( lo.lmode, 
         0, 'none',           /* Mon Lock equivalent */
         1, 'null',           /* N */
         2, 'row-S (SS)',     /* L */
         3, 'row-X (SX)',     /* R */
         4, 'share (S)',      /* S */
         5, 'S/Row-X (SSX)',  /* C */
         6, 'excl (X)',       /* X */
         TO_CHAR(lo.lmode)) lmode,
       DECODE( lo.request, 
         0, 'none',           /* Mon Lock equivalent */
         1, 'null',           /* N */
         2, 'row-S (SS)',     /* L */
         3, 'row-X (SX)',     /* R */
         4, 'share (S)',      /* S */
         5, 'S/Row-X (SSX)',  /* C */
         6, 'excl (X)',       /* X */
         TO_CHAR(lo.request)) request,
       lo.ctime ctime,
       DECODE(lo.block,
         0, 'No Block',
         1, 'Blocking',
         2, 'Global',
         TO_CHAR(lo.block)) blkothr,
       us.name owner,
       ob.name image,
       TO_CHAR( DECODE(se.row_wait_obj#,-1,' ',se.row_wait_block#) ) lblock,
       TO_CHAR( DECODE(se.row_wait_obj#,-1,' ',se.row_wait_row#)) lrow
  FROM v$lock lo,
       v$session se,
       sys.obj$ ob,
       sys.user$ us
 WHERE se.sid = lo.sid
   AND lo.id1 = ob.obj#(+)
   AND ob.owner# = us.user#(+)
   AND se.type != 'BACKGROUND'
   AND lo.id2 = 0
 UNION ALL
SELECT se.username,
       se.sid,
       DECODE( se.command,
               0, 'No command',
               1, 'CREATE TABLE',
               2, 'INSERT',
               3, 'SELECT',
               4, 'CREATE CLUSTER',
               5, 'ALTER CLUSTER',
               6, 'UPDATE',
               7, 'DELETE',
               8, 'DROP CLUSTER',
               9, 'CREATE INDEX',
               10, 'DROP INDEX',
               11, 'ALTER INDEX',
               12, 'DROP TABLE',
               13, 'CREATE SEQUENCE',
               14, 'ALTER SEQUENCE',
               15, 'ALTER TABLE',
               16, 'DROP SEQUENCE',
               17, 'GRANT',
               18, 'REVOKE',
               19, 'CREATE SYNONYM',
               20, 'DROP SYNONYM',
               21, 'CREATE VIEW',
               22, 'DROP VIEW',
               23, 'VALIDATE INDEX',
               24, 'CREATE PROCEDURE',
               25, 'ALTER PROCEDURE',
               26, 'LOCK TABLE',
               27, 'NO OPERATION',
               28, 'RENAME',
               29, 'COMMENT',
               30, 'AUDIT',
               31, 'NOAUDIT',
               32, 'CREATE DATABASE LINK',
               33, 'DROP DATABASE LINK',
               34, 'CREATE DATABASE',
               35, 'ALTER DATABASE',
               36, 'CREATE ROLLBACK SEGMENT',
               37, 'ALTER ROLLBACK SEGMENT',
               38, 'DROP ROLLBACK SEGMENT',
               39, 'CREATE TABLESPACE',
               40, 'ALTER TABLESPACE',
               41, 'DROP TABLESPACE',
               42, 'ALTER SESSION',
               43, 'ALTER USER',
               44, 'COMMIT',
               45, 'ROLLBACK',
               46, 'SAVEPOINT',
               47, 'PL/SQL EXECUTE',
               48, 'SET TRANSACTION', 
               49, 'ALTER SYSTEM SWITCH LOG',
               50, 'EXPLAIN',
               51, 'CREATE USER',
               52, 'CREATE ROLE',
               53, 'DROP USER',
               54, 'DROP ROLE',
               55, 'SET ROLE',
               56, 'CREATE SCHEMA',
               57, 'CREATE CONTROL FILE',
               58, 'ALTER TRACING',
               59, 'CREATE TRIGGER',
               60, 'ALTER TRIGGER',
               61, 'DROP TRIGGER',
               62, 'ANALYZE TABLE',
               63, 'ANALYZE INDEX',
               64, 'ANALYZE CLUSTER',
               65, 'CREATE PROFILE',
               67, 'DROP PROFILE',
               68, 'ALTER PROFILE',
               69, 'DROP PROCEDURE',
               70, 'ALTER RESOURCE COST',
               71, 'CREATE SNAPSHOT LOG',
               72, 'ALTER SNAPSHOT LOG',
               73, 'DROP SNAPSHOT LOG',
               74, 'CREATE SNAPSHOT',
               75, 'ALTER SNAPSHOT',
               76, 'DROP SNAPSHOT',
               79, 'ALTER ROLE',
               85, 'TRUNCATE TABLE',
               86, 'TRUNCATE CLUSTER',
               88, 'ALTER VIEW',
               91, 'CREATE FUNCTION',
               92, 'ALTER FUNCTION',
               93, 'DROP FUNCTION',
               94, 'CREATE PACKAGE',
               95, 'ALTER PACKAGE',
               96, 'DROP PACKAGE',
               97, 'CREATE PACKAGE BODY',
               98, 'ALTER PACKAGE BODY',
               99, 'DROP PACKAGE BODY',
         TO_CHAR(se.command) ) command,
       DECODE(lo.type,
         'MR', 'Media Recovery',
         'RT', 'Redo Thread',
         'UN', 'User Name',
         'TX', 'Transaction',
         'TM', 'DML',
         'UL', 'PL/SQL User Lock',
         'DX', 'Distributed Xaction',
         'CF', 'Control File',
         'IS', 'Instance State',
         'FS', 'File Set',
         'IR', 'Instance Recovery',
         'ST', 'Disk Space Transaction',
         'TS', 'Temp Segment',
         'IV', 'Library Cache Invalidation',
         'LS', 'Log Start or Switch',
         'RW', 'Row Wait',
         'SQ', 'Sequence Number',
         'TE', 'Extend Table',
         'TT', 'Temp Table',
         'JQ', 'Job Queue',
         lo.type) ltype,
       DECODE( lo.lmode, 
         0, 'none',           /* Mon Lock equivalent */
         1, 'null (NULL)',    /* N */
         2, 'row-S (SS)',     /* L */
         3, 'row-X (SX)',     /* R */
         4, 'share (S)',      /* S */
         5, 'S/Row-X (SSX)',  /* C */
         6, 'excl (X)',       /* X */
         lo.lmode) lmode,
       DECODE( lo.request, 
         0, 'none',           /* Mon Lock equivalent */
         1, 'null (NULL)',    /* N */
         2, 'row-S (SS)',     /* L */
         3, 'row-X (SX)',     /* R */
         4, 'share (S)',      /* S */
         5, 'S/Row-X (SSX)',  /* C */
         6, 'excl (X)',       /* X */
         TO_CHAR(lo.request)) request,
       lo.ctime ctime,
       DECODE(lo.block,
         0, 'No Block',
         1, 'Blocking',
         2, 'Global',
         TO_CHAR(lo.block)) blkothr,
       'SYS' owner,
       ro.name image,
       TO_CHAR( DECODE(se.row_wait_obj#,-1,' ',se.row_wait_block#) ) lblock,
       TO_CHAR( DECODE(se.row_wait_obj#,-1,' ',se.row_wait_row#)) lrow
  FROM v$lock lo,
       v$session se,
       v$transaction tr,
       v$rollname ro
 WHERE se.taddr IS NOT NULL
   AND se.sid = lo.sid
   AND lo.id2 != 0
   AND se.taddr = tr.addr(+)
   AND tr.xidusn = ro.usn(+)
 ORDER BY sid 
/

