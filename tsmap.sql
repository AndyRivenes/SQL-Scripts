--  FILE:   tsmap.sql
--
--  AUTHOR: Andy Rivenes, arivenes@appsdba.com, www.appsdba.com
--          (The autoextending and free space code was based on a 
--           free space script originally written by Neil Jensen)
--          Copyright (C) 1999-2000 AppsDBA Consulting
--  DATE:   08/24/1999
--
--  DESCRIPTION:
--          Query to display tablespace space.
--          NOTE: This query will reflect autoextension and works for
--                databases with and without autoextending tablespaces.
--          
--  REQUIREMENTS:
--          SELECT access to the following SYS views:
--		dba_data_files
--		dba_free_space
--              dba_tablespaces
--              filext$
--              v$parameter
--		
--  MODIFICATIONS:
--          A. Rivenes, 01/12/2000, Corrected a problem with autoextending
--                                  tablespaces that have datafiles that
--                                  have been resized greater than their
--                                  MAXEXTEND size.
--          A. Rivenes, 02/25/2000, Added Database totals at the end.
--
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
SET TRIMSPOOL on;
SET SERVEROUTPUT on;
--
PROMPT Tablespace Space Map ;
PROMPT ;
--
DECLARE
--
  var_stmt              VARCHAR2(4000);
  cursor_name           INTEGER;
  ret                   INTEGER;
  var_blksiz            NUMBER;
  var_test              CHAR(1);
  --
  var_tsnam             VARCHAR2(30);
  var_stat              VARCHAR2(9);
  var_cre_sz            NUMBER;
  var_max_fr            NUMBER;
  var_tot_fr            NUMBER;
  var_extnd             NUMBER;
  var_pct_fr            NUMBER;
  --
  var_tot_alloc         NUMBER;
  var_tot_used          NUMBER;
  var_tot_unused        NUMBER;
--
BEGIN
  --
  DBMS_OUTPUT.ENABLE(400000);
  --
  BEGIN
    SELECT 'X'
      INTO var_test
      FROM sys.dba_objects
     WHERE owner = 'SYS'
       AND object_name = 'FILEXT$';
    --
    SELECT TO_NUMBER(value) 
      INTO var_blksiz
      FROM v$parameter
     WHERE name = 'db_block_size';
    --
    var_stmt := 'SELECT data_files.tablespace_name, '||
                     'ts.status, '||
                     'tot_alloc_byt/1024/1024, '||
                     'NVL(ROUND(max_free_byt/1024/1024,2),0), '||
                     'NVL(ROUND(tot_free_byt/1024/1024,2),0), '||
                     'NVL(ROUND( ((tot_extnd_blk * '||var_blksiz||') + tot_alloc_byt)/1024/1024,2 ),0), '||
                     'NVL(ROUND( ( ( tot_free_byt + '||
                                'DECODE( tot_extnd_blk,NULL,0, '||
                                                      '(tot_extnd_blk * '||var_blksiz||') ) '||
                               ') / DECODE( tot_extnd_blk,NULL,tot_alloc_byt, '||
                                                         'tot_alloc_byt + (tot_extnd_blk * '||var_blksiz||') ) * 100 '|| 
                            '), 2),0) pctfr '||
                'FROM ( SELECT tablespace_name, '||
                              'SUM(bytes) tot_alloc_byt '||
                         'FROM sys.dba_data_files '||
                        'GROUP BY tablespace_name ) data_files, '||
                     '( SELECT tablespace_name, '||
                              'MAX(bytes) max_free_byt, '||
                              'SUM(bytes) tot_free_byt '||
                         'FROM sys.dba_free_space '||
                        'GROUP BY tablespace_name ) free_space, '||
                     '( SELECT tablespace_name, '|| 
                              'SUM(DECODE(SIGN(maxextend - blocks),-1,0,(maxextend - blocks))) tot_extnd_blk '|| 
                         'FROM sys.filext$, '|| 
                              'sys.dba_data_files '|| 
                        'WHERE filext$.file# = dba_data_files.file_id '|| 
                        'GROUP BY tablespace_name  ) extnd, '||
                     'sys.dba_tablespaces ts '||
               'WHERE data_files.tablespace_name = free_space.tablespace_name(+) '||
                 'AND data_files.tablespace_name = extnd.tablespace_name(+) '||
                 'AND data_files.tablespace_name = ts.tablespace_name '||
               'ORDER BY pctfr DESC';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    var_stmt := 'SELECT data_files.tablespace_name, '||
                     'ts.status, '||
                     'data_files.tot_create_byt /1024/1024, '||
                     'NVL(ROUND(free_space.max_free_byt / 1024/1024,2),0), '||
                     'NVL(ROUND(free_space.tot_free_byt / 1024/1024,2),0), '||
                     '0, '||
                     'NVL(ROUND((free_space.tot_free_byt/data_files.tot_create_byt*100),2),0) pctfr '||
                'FROM ( SELECT tablespace_name, '||
                             'SUM(bytes) tot_create_byt '||       
                        'FROM sys.dba_data_files '||
                       'GROUP BY tablespace_name ) data_files, '||
                    '( SELECT tablespace_name, '||
                             'MAX(bytes) max_free_byt, '||
                             'SUM(bytes) tot_free_byt '||
                        'FROM sys.dba_free_space '||
                       'GROUP BY tablespace_name ) free_space, '||
                    'sys.dba_tablespaces ts '||
              'WHERE data_files.tablespace_name = free_space.tablespace_name(+) '||
                'AND data_files.tablespace_name = ts.tablespace_name '||
              'ORDER BY pctfr DESC';
  END;
  --
  cursor_name := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(cursor_name, var_stmt, DBMS_SQL.V7);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 1, var_tsnam, 30);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 2, var_stat, 9);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 3, var_cre_sz);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 4, var_max_fr);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 5, var_tot_fr);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 6, var_extnd);
  DBMS_SQL.DEFINE_COLUMN(cursor_name, 7, var_pct_fr);
  --
  ret := DBMS_SQL.EXECUTE(cursor_name);
  DBMS_OUTPUT.PUT_LINE( 'Tablespace                                         Max Contig      Total Free   Extends  Pct Free' );
  DBMS_OUTPUT.PUT_LINE( 'Name                          Status    Alloc(MB)  Alloc Free(MB)  Alloc(MB)    To(MB)   Spc Avail' );
  DBMS_OUTPUT.PUT_LINE( '----------------------------  -------  ----------  --------------  ----------  --------  ---------' );
  WHILE DBMS_SQL.FETCH_ROWS(cursor_name) > 0 LOOP
    -- get column values for the row
    DBMS_SQL.COLUMN_VALUE(cursor_name, 1, var_tsnam);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 2, var_stat);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 3, var_cre_sz);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 4, var_max_fr);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 5, var_tot_fr);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 6, var_extnd);
    DBMS_SQL.COLUMN_VALUE(cursor_name, 7, var_pct_fr);
    --
    DBMS_OUTPUT.PUT_LINE( RPAD(var_tsnam,30,'  ')||RPAD(var_stat,9,'  ')
                          ||LPAD(TO_CHAR(var_cre_sz,'999,990'),10,' ')||'  '
                          ||LPAD(TO_CHAR(var_max_fr,'999,990'),14,' ')||'  '
                          ||LPAD(TO_CHAR(var_tot_fr,'999,990'),10,' ')||'  '
                          ||LPAD(TO_CHAR(var_extnd,'999,990'),8,' ')||'  '
                          ||LPAD(TO_CHAR(var_pct_fr,'999.90'),9,' ') );  
  END LOOP;
  DBMS_SQL.CLOSE_CURSOR(cursor_name);
  --
  SELECT SUM(bytes)/1024/1024
    INTO var_tot_alloc
    FROM dba_data_files;
  --
  SELECT SUM(bytes)/1024/1024
    INTO var_tot_unused
    FROM dba_free_space;
  --
  SELECT SUM(bytes)/1024/1024
    INTO var_tot_used
    FROM dba_segments;
  --
--  DBMS_OUTPUT.PUT_LINE(CHR(13));
  DBMS_OUTPUT.PUT_LINE(CHR(10));
  DBMS_OUTPUT.PUT_LINE( 'Database Totals:                            Total           Total       Total  ' );
  DBMS_OUTPUT.PUT_LINE( '                                        Alloc(MB)        Used(MB)    Free(MB)  ' );
  DBMS_OUTPUT.PUT_LINE( '                                       ----------      ----------  ----------  ' );
  --
  DBMS_OUTPUT.PUT_LINE( LPAD(TO_CHAR(var_tot_alloc,'99,999,990'),49,' ')||'  '
                        ||LPAD(TO_CHAR(var_tot_used,'99,999,990'),14,' ')||'  '
                        ||LPAD(TO_CHAR(var_tot_unused,'999,990'),10,' ') );
  --
END;
/
