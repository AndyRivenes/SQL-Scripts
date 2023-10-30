--   FILE:     run_sysstats.sql
--
--
--   AUTHOR:   Tom Kyte
--
--   DATE:     Unknown
--
--   DESCRIPTION:
--             This script is based on Tom Kyte's runstats utility. It was created for
--             an AskTOM Office Hours session for Database In-Memory to handle an issue
--             with v$mystat where 'IM simd' statistics were not being shown. This script
--             was changed to use v$sysstat where those statistics are available. This
--             is problematic where multiple users are executing and is really only 
--             suitable for a single active user system. The use of v$latch and v$timer
--             from the original runstats utility have been removed since usage of this 
--             version is really just meant to facilitate seeing system level statistics
--             that are not available at the session level. The run_stats global temporary
--             table has also been changed to a regular table to preserve information 
--             across database sessions.
--
--             Everything needed to install and run the utility has been included. Since
--             this utility needs certain system privileges it is expected that
--             this utility will be installed into a privileged account.
--
--   WARNING:
--             Use this utility at your own risk. This utility was created for a specific
--             purpose and is meant for testing only.
--
--   REQUIREMENTS:
--             Requires SELECT privileges on SYS.V_$STATNAME, SYS.V_$SYSSTAT,
--             
--             NOTE: These must be DIRECTLY granted privileges, not granted via a ROLE.
--
--             Requires CREATE TABLE privilege to create the run_stats table.
--
--             Requires CREATE PROCEDURE to create the package rs_pkg.
--
--             Requires CREATE PUBLIC SYNONYM to create the rs_pkg public synonym.
--             The AskTOM Office Hours scripts call runstats_pkg rather than the
--             run_sysstats_pkg. A create public synonym command is included at the
--             bottom of this script that can be used to call runstats_pkg (this is the
--             original package name).
--
--   MODIFICATIONS:
--             1.0,  08/18/21, A. Rivenes,
--               Renamed to run_sysstat, added CREATE VIEW privilege and converted 
--               to use v$sysstat due to a bug with v$mystat. Does require exclusive
--               access to work correctly.
--
--             1.1,  10/27/2023, A. Rivenes,
--               Updated help section with corrected package name due to a typo.
--
--             1.2,  10/30/2023, A. Rivenes,
--               Separated the output print into a new rs_output procedure so that the 
--               current output can be re-displayed, added an INMEMORY display option 
--               for IM related statistics.
--
PROMPT >> This script requires an account to install the RUN_SYSSTATS utility.
PROMPT >> ;
PROMPT >> Please exit this script (using Control-C or break) if you
PROMPT >> do not wish to continue.
PROMPT >> ;
PROMPT >> Press [Return] to continue.
--
ACCEPT runans
--
ACCEPT runstats_usr prompt 'Enter the ORACLE userid for the RUNSTATS account:  '
PROMPT
ACCEPT runstats_pwd prompt 'Enter the ORACLE password for the RUNSTATS account:  ' HIDE
PROMPT
--
REM Ensure you can connect to the RUNSTATS account using the password given
--
CONNECT &runstats_usr/&runstats_pwd
--
PROMPT >> If the previous connect failed, please exit this script
PROMPT >> (using Control-C or break) and restart, otherwise press [Return]
ACCEPT rinstans
--
-- Insure that system privileges have been granted.
--
PROMPT >> The following system privileges be granted to the runstats schema:
PROMPT >> ;
PROMPT >>   GRANT SELECT ON sys.v_$statname TO runstats_schema;
PROMPT >>   GRANT SELECT ON sys.v_$sysstat TO runstats_schema;
PROMPT >>   GRANT CREATE TABLE TO runstats_schema;
PROMPT >>   GRANT CREATE VIEW TO runstats_schema;
PROMPT >>   GRANT CREATE PROCEDURE TO runstats_schema;
PROMPT >>   GRANT CREATE PUBLIC SYNONYM TO runstats_schema;
PROMPT >> ;
PROMPT >> Requires a privileged (SYSDBA) account to create these privileges.
PROMPT >> ;
PROMPT >> Please exit this script (using Control-C or break) if you
PROMPT >> do not wish to continue.
PROMPT >> ;
PROMPT >> Press [Return] to continue.
--
ACCEPT sysans
--
ACCEPT sysdba_usr prompt 'Enter a SYSDBA ORACLE userid:  '
PROMPT
ACCEPT sysdba_pwd prompt 'Enter the SYSDBA ORACLE password:  ' HIDE
PROMPT
--
REM Ensure you can connect to the SYSDBA account using the password given
--
CONNECT &sysdba_usr/&sysdba_pwd AS SYSDBA
--
PROMPT >> If the previous connect failed, please exit this script
PROMPT >> (using Control-C or break) and restart, otherwise press [Return]
ACCEPT sinstans
--
SPOOL sysdba_install.log;
--
-- Grant system privileges
--
GRANT SELECT ON sys.v_$statname TO &runstats_usr;
GRANT SELECT ON sys.v_$sysstat TO &runstats_usr;
GRANT CREATE TABLE TO &runstats_usr;
GRANT CREATE VIEW TO &runstats_usr;
GRANT CREATE PROCEDURE TO &runstats_usr;
GRANT CREATE PUBLIC SYNONYM TO &runstats_usr;
--
-- Install the runstats utility
--
CONNECT &runstats_usr/&runstats_pwd
--
SPOOL run_sysstats_install.log;
SET SERVEROUTPUT on;
WHENEVER SQLERROR CONTINUE;
--
set echo on
--
DROP TABLE run_sysstats;
--
CREATE TABLE run_sysstats 
  ( 
    runid varchar2(15), 
    name varchar2(80), 
    value int
  );
--
CREATE OR REPLACE VIEW sysstats
AS 
SELECT
  'STAT...' || a.name name, a.value
FROM
  v$sysstat a;
--
DELETE FROM run_sysstats;
COMMIT;
--
CREATE OR REPLACE PACKAGE run_sysstats_pkg
AS
  PROCEDURE rs_start;
  --
  PROCEDURE rs_middle;
  --
  PROCEDURE rs_stop(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL);
  --
  PROCEDURE rs_results(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL);
  --
  PROCEDURE version;
  --
  PROCEDURE help;
END run_sysstats_pkg;
/
--
CREATE OR REPLACE PACKAGE BODY run_sysstats_pkg
AS
  g_version_txt   VARCHAR2(60)
        := 'run_sysstats - Version 1.2, October 30, 2023';
  --
  -- Procedure to mark the start of the two runs
  --
  PROCEDURE rs_start
  IS 
  BEGIN
    DELETE FROM run_sysstats;
    --
    INSERT INTO run_sysstats 
    SELECT 'before', sysstats.*
    FROM sysstats;
  END rs_start;
  --
  -- Procedure to run between the two runs
  --
  PROCEDURE rs_middle
  IS
  BEGIN
    INSERT INTO run_sysstats 
    SELECT 'after 1', sysstats.*
    FROM sysstats;
  END rs_middle;
  --
  -- Procedure to run after the two runs
  --
  PROCEDURE rs_stop(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL)
  IS
  BEGIN
    INSERT INTO run_sysstats 
    SELECT 'after 2', sysstats.*
    FROM sysstats;
    --
    -- Call rs_results to display output stats
    --
    rs_results(p_difference_threshold, p_output);
  END rs_stop;
  --
  -- Display results
  --
  PROCEDURE rs_results(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL)
  IS
  BEGIN
    DBMS_OUTPUT.put_line
    ( rpad( 'Name', 50 ) || lpad( 'Run1', 12 ) || 
      lpad( 'Run2', 12 ) || lpad( 'Diff', 12 ) );
    --
    -- Output choice
    --
    IF p_output = 'WORKLOAD' THEN 
      FOR x IN 
      ( SELECT 
          RPAD( a.name, 50 ) || 
          TO_CHAR( b.value-a.value, '999,999,999' ) || 
          TO_CHAR( c.value-b.value, '999,999,999' ) || 
          TO_CHAR( ( (c.value-b.value)-(b.value-a.value)), '999,999,999' ) data
        FROM
          run_sysstats a,
          run_sysstats b,
          run_sysstats c
        WHERE
           a.name = b.name
           AND b.name = c.name
           AND a.runid = 'before'
           AND b.runid = 'after 1'
           AND c.runid = 'after 2'
           AND ABS( (c.value-b.value) - (b.value-a.value) ) 
             > p_difference_threshold
           AND c.name IN
            (
              'STAT...Elapsed Time',
              'STAT...DB Time',
              'STAT...CPU used by this session',
              'STAT...parse time cpu',
              'STAT...recursive cpu usage',
              'STAT...session logical reads',
              'STAT...physical reads',
              'STAT...physical reads cache',
              'STAT...physical reads direct',
              'STAT...sorts (disk)',
              'STAT...sorts (memory)',
              'STAT...sorts (rows)',
              'STAT...queries parallelized',
              'STAT...redo size',
              'STAT...user commits'
            )
         ORDER BY
           ABS( (c.value-b.value)-(b.value-a.value))
      ) LOOP
        DBMS_OUTPUT.put_line( x.data );
      END LOOP;
    ELSIF  p_output = 'INMEMORY' THEN
      FOR x IN 
      ( SELECT 
          RPAD( a.name, 50 ) || 
          TO_CHAR( b.value-a.value, '999,999,999' ) || 
          TO_CHAR( c.value-b.value, '999,999,999' ) || 
          TO_CHAR( ( (c.value-b.value)-(b.value-a.value)), '999,999,999' ) data
        FROM
          run_sysstats a,
          run_sysstats b,
          run_sysstats c
        WHERE
           a.name = b.name
           AND b.name = c.name
           AND a.runid = 'before'
           AND b.runid = 'after 1'
           AND c.runid = 'after 2'
           AND (
             (a.name LIKE 'STAT...IM%')
	           OR (a.name LIKE 'STAT...cell%')
             OR ( a.name IN (
                 'STAT...CPU used by this session',
                 'STAT...physical reads',
                 'STAT...session logical reads',
                 'STAT...session logical reads - IM',
                 'STAT...session pga memory',
                 'STAT...table scans (IM)',
                 'STAT...table scan disk IMC fallback'
               )
             )
           )
           AND ABS( (c.value-b.value) - (b.value-a.value) ) 
             > p_difference_threshold
         ORDER BY a.name,
           ABS( (c.value-b.value)-(b.value-a.value))
      ) LOOP
        DBMS_OUTPUT.put_line( x.data );
      END LOOP;
    ELSE
      -- Assume the default of NULL, all stats will be displayed
      FOR x IN 
      ( SELECT 
          RPAD( a.name, 50 ) || 
          TO_CHAR( b.value-a.value, '999,999,999' ) || 
          TO_CHAR( c.value-b.value, '999,999,999' ) || 
          TO_CHAR( ( (c.value-b.value)-(b.value-a.value)), '999,999,999' ) data
        FROM
          run_sysstats a,
          run_sysstats b,
          run_sysstats c
        WHERE
           a.name = b.name
           AND b.name = c.name
           AND a.runid = 'before'
           AND b.runid = 'after 1'
           AND c.runid = 'after 2'
           AND ABS( (c.value-b.value) - (b.value-a.value) ) 
             > p_difference_threshold
         ORDER BY a.name,
           ABS( (c.value-b.value)-(b.value-a.value))
      ) LOOP
        DBMS_OUTPUT.put_line( x.data );
      END LOOP;
    END IF;
  END rs_results;
  --
  -- Display version
  --
  PROCEDURE version
  IS
  -- 
  BEGIN
    IF LENGTH(g_version_txt) > 0 THEN
      dbms_output.put_line(' ');
      dbms_output.put_line(g_version_txt);
    END IF;
  -- 
  END version;
  --
  -- Display help
  --
  PROCEDURE help 
  IS
  -- 
  -- Lists help menu
  --
  BEGIN
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(g_version_txt);
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure rs_start');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the start of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure rs_middle');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the middle of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure rs_stop');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the end of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Parameters:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'p_difference_threshold - Controls the output. Only stats greater');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'than p_difference_threshold will be displayed.');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'p_output - Controls stats displayed.');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'  Default is NULL, all stats displayed (or any unsupported parameter).');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'  WORKLOAD, only workload related stats are displayed.');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'  INMEMORY, Database In-Memory specific stats are displayed.');
    --
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Example:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Add the following calls to your test code:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'    exec run_sysstats_pkg.rs_start;');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'    exec run_sysstats_pkg.rs_middle;');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'    exec run_sysstats_pkg.rs_stop;');
    --
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('NOTE: In SQL*Plus set the following for best results:');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Before 10g:   SET SERVEROUTPUT ON SIZE 1000000');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'10g or later: SET SERVEROUTPUT ON');
  END help;
  --
END run_sysstats_pkg;
/
--
-- Grant privileges on run_sysstats objects
--
SET escape "^";
CREATE PUBLIC SYNONYM run_sysstats_pkg FOR &runstats_usr^.run_sysstats_pkg;
GRANT EXECUTE ON run_sysstats_pkg TO PUBLIC;
--
-- DROP PUBLIC SYNONYM runstats_pkg;
-- CREATE PUBLIC SYNONYM runstats_pkg FOR &runstats_usr^.run_sysstats_pkg;
-- 
--
EXIT;
