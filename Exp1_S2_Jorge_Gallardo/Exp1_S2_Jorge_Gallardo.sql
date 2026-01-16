--=============================================
-- SUMATIVA 1 PROGRAMACION DE BASES DE DATOS
--=============================================

-- SET QUE PERMITE EL OUTPUT DEL BLOQUE PL/SQL
SET serveroutput on; 

-- VARIABLE BIND USADA PARA LA FECHA DE SISTEMA BASE DE DATOS
VAR b_fecha_proc DATE
EXEC :b_fecha_proc := SYSDATE;

DECLARE

-- VARIABLES CONTADOR Y VERIFICACION DEL TOTAL DE REGISTROS INGRESADOS EN TABLA USUARIO_CLAVE
v_contador NUMBER := 0;
v_total_registros NUMBER; 
v_total_emp NUMBER(2); 

-- VARIABLES DE RECUPERACION DE DATOS EMPLEADO
v_id_emp empleado.id_emp%TYPE;
v_numrun_emp empleado.numrun_emp%TYPE;
v_dvrun_emp empleado.dvrun_emp%TYPE;
v_pnombre_emp empleado.pnombre_emp%TYPE; 
v_snombre_emp empleado.pnombre_emp%TYPE;
v_appaterno_emp empleado.pnombre_emp%TYPE;
v_apmaterno_emp empleado.pnombre_emp%TYPE;
v_fecha_nac_emp empleado.fecha_nac%TYPE;
v_estado_civil VARCHAR2(25); 
v_nombre_completo_empleado usuario_clave.nombre_empleado%TYPE; 

-- VARIABLE USADA PARA ITERAR DESDE UN EMP INICIAL
v_emp_inicial NUMBER;  

-- VARIABLES PARA NOMBRE DE USUARIO
v_inicial_ecivil VARCHAR2(1); 
v_3letras_pnombre VARCHAR2(3);
v_largo_pnombre NUMBER;
v_ult_digito_sueldob NUMBER; 
v_annios_trabajo VARCHAR2(2); 

-- VARIABLES PARA CLAVE USUARIO
v_tercer_digito_run NUMBER;
v_anio_nacimiento_aumentado NUMBER; 
v_sueldo_base NUMBER;
v_digitos_sueldob VARCHAR2(3);
v_id_estado_civil NUMBER; 
v_letras_appaterno VARCHAR2(2);
v_numeros_fecha NUMBER; 
v_fecha_contrato DATE;

-- Variable uso fecha de proceso donde se utiliza variable BIND
v_fecha_proceso DATE := SYSDATE;

-- VARIABLES QUE ALMACENAN NOMBRE USUARIO Y CLAVE USUARIO
v_nombre_usuario usuario_clave.nombre_usuario%TYPE; 
v_clave_usuario usuario_clave.clave_usuario%TYPE;

BEGIN
    
    -- TRUNCATE PARA LA EJECUCION DINAMICA SOBRE LA TABLA USUARIO_CLAVE
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';
    
    -- ALMACENA EL TOTAL DE EMPLEADOS EN LA VARIABLE V_TOTAL_EMP --> USO FOR
    SELECT 
    COUNT(id_emp)
    INTO v_total_emp
    FROM empleado
;    
    -- PERMITE OBTENER EL ID_EMP DEL PRIMERO DE LA TABLA EMPLEADO
    SELECT 
    id_emp
    INTO v_emp_inicial
    FROM empleado
    FETCH FIRST 1 ROW ONLY
; 
    -- FOR DE ITERACION QUE UTILIZA LA VARIABLE V_TOTAL_EMP COMO LIMITE
    FOR i IN 1..v_total_emp LOOP
    
        -- SELECT QUE PERMITE OBTENER TODOS LOS VALORES QUE NECESARIOS POR MEDIO DE INTO 
        -- PARA CONSTRUIR NOMBRE DE USUARIO Y CLAVE USUARIO 
        
        SELECT     
            -- RECUPERACION DE VALORES
            e.id_emp, 
            e.numrun_emp, 
            e.dvrun_emp,
            e.pnombre_emp,
            e.snombre_emp,
            e.appaterno_emp,
            e.apmaterno_emp,
            ec.nombre_estado_civil,         
            e.fecha_contrato,
            e.fecha_nac,
            e.sueldo_base,
            e.id_estado_civil
                     
        INTO 
            -- VARIABLES PARA RECUPERACION DE VALORES
             v_id_emp, 
             v_numrun_emp, 
             v_dvrun_emp,             
             v_pnombre_emp,
             v_snombre_emp,
             v_appaterno_emp,
             v_apmaterno_emp,              
             v_estado_civil,   
             v_fecha_contrato,
             v_fecha_nac_emp,            
             v_sueldo_base,
             v_id_estado_civil
                         
        FROM empleado e
        INNER JOIN estado_civil ec ON ec.id_estado_civil = e.id_estado_civil
        
        -- V_EMP_INICIAL PERMITE OBTENER LOS DATOS DE 1 EMPLEADO
        -- ESTE VALOR SE MODIFICA PARA OBTENER EL TOTAL DE REGISTROS
        WHERE e.id_emp = v_emp_inicial 
        ORDER BY e.id_emp 
        
-- FIN SENTENCIA SELECT        
; 
        --CALCULOS CON VARIABLES
        v_nombre_completo_empleado := v_pnombre_emp || ' ' || NVL(v_snombre_emp, '') || ' ' || v_appaterno_emp || ' ' || v_apmaterno_emp;
        v_inicial_ecivil := LOWER(SUBSTR(v_estado_civil,1,1)); 
        v_3letras_pnombre := SUBSTR(v_pnombre_emp,1,3);
        v_largo_pnombre := LENGTH(v_pnombre_emp);
        v_ult_digito_sueldob := MOD(v_sueldo_base, 10);
        v_tercer_digito_run := SUBSTR(TO_CHAR(v_numrun_emp),3,1); 
        v_anio_nacimiento_aumentado := EXTRACT(YEAR FROM v_fecha_nac_emp)  + 2;
        v_digitos_sueldob := SUBSTR(TO_CHAR(v_sueldo_base -1 , '00000000'),-3); 
        
        v_annios_trabajo :=  
        
            -- CASE UTILIZADO PARA AÑOS DE SERVICIO OTORGA "X" CUANDO EL VALOR OBTENIDO ES MENOR A 10
            -- UTILIZA MONTHS_BETWEEN PARA OBTENER EL TOTAL DE MESES, DIVIDE ESE VALOR POR 12 PARA OBTENER EL TOTAL DE AÑOS
            -- ELIMINA LA PARTE DECIMAL POR MEDIO DE TRUNC 
            
            CASE
                WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_contrato)/12) < 10 
                    THEN TO_CHAR(TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_contrato)/12)) || 'X' 
            ELSE
                TO_CHAR(TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_contrato)/12))
            END;
                  
        v_letras_appaterno := 
        
            -- CASE UTILIZADO PARA DEFINIR LOS VALORES OBTENIDOS DEL APELLIDO PATERNO
            -- VALOR ALMACENADO EN LA VARIABLE v_appaterno_emp ESTO SEGUN 
            -- EL ID DEL ESTADO CIVIL VALOR ALMACENADO EN LA VARIABLE v_id_estado_civil
            
            CASE
                WHEN v_id_estado_civil = 10 OR v_id_estado_civil = 60 THEN
                    LOWER(SUBSTR(v_appaterno_emp, 1,2))
                WHEN v_id_estado_civil = 20 OR v_id_estado_civil = 30 THEN
                    LOWER(SUBSTR(v_appaterno_emp, 1,1)) || LOWER(SUBSTR(v_appaterno_emp, -1,1))
                WHEN v_id_estado_civil = 40 THEN
                    LOWER(SUBSTR(v_appaterno_emp, -3,1)) || LOWER(SUBSTR(v_appaterno_emp, -2,1))
                WHEN v_id_estado_civil = 50 THEN
                    LOWER(SUBSTR(v_appaterno_emp, -1,2))
           END;
           
        v_numeros_fecha :=  
        
            --PERMITE EXTRAER EL NUMERO CORRELATIVO AL MES Y AÑO DE V_FECHA_PROCESO (SYSDATE POR MEDIO DE LA VARIABLE BIND)
            EXTRACT(MONTH FROM v_fecha_proceso) || EXTRACT(YEAR FROM v_fecha_proceso);           

        -- VALORES OBTENIDOS A VARIABLE:  V_NOMBRE USUARIO
        v_nombre_usuario :=  v_inicial_ecivil || v_3letras_pnombre || v_largo_pnombre || 
            '*' || v_ult_digito_sueldob || v_dvrun_emp || v_annios_trabajo; 
            
        -- VALORES OBTENIDOS A VARIABLE: V_CLAVE_USUARIO    
        v_clave_usuario := v_tercer_digito_run || v_anio_nacimiento_aumentado || v_digitos_sueldob ||
            v_letras_appaterno || v_id_emp || v_numeros_fecha; 
            
        DBMS_OUTPUT.PUT_LINE('NOMBRE EMPLEADO: ' || v_nombre_completo_empleado);    
        DBMS_OUTPUT.PUT_LINE('ID EMPLEADO: ' || v_emp_inicial);
        DBMS_OUTPUT.PUT_LINE('NOMBRE USUARIO: ' || v_nombre_usuario);
        DBMS_OUTPUT.PUT_LINE('CLAVE USUARIO: ' || v_clave_usuario);
        DBMS_OUTPUT.PUT_LINE('FECHA ACTUAL: ' ||  v_fecha_proceso);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- INSERTAMOS LOS VALORES EN LA TABLA USUARIO_CLAVE
        INSERT INTO usuario_clave(id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario)
        VALUES(v_id_emp, v_numrun_emp, v_dvrun_emp, v_nombre_completo_empleado, v_nombre_usuario, v_clave_usuario); 
        
        -- SE ACTUALIZA AL FINAL LA VARIABLE V_EMP_INICIAL PARA QUE RECORRA POR MEDIO DEL FOR EL TOTAL DE REGISTROS
         v_emp_inicial := v_emp_inicial + 10;
         
         -- CONTADOR PARA REALIZAR EL IF DE COMPARACION PARA EL COMMIT FINAL
         v_contador := v_contador +1; 
    END LOOP;
-- CIERRE LOOP FOR    
    
    -- SELECT QUE PERMITE OBTENER EL TOTAL DE REGISTROS INGRESADOS A LA TABLA USUARIO_CLAVE
    SELECT COUNT(id_emp) INTO v_total_registros FROM usuario_clave;
    
    --IF QUE PERMITE COMPARAR POR MEDIO DEL CONTADOR EL TOTAL DE REGISTROS DE LA TABLA USUARIO_CLAVE Y EL TOTAL DE EMPLEADOS
    IF v_contador = v_total_registros AND v_contador = v_total_emp THEN 
    
        -- MENSAJE Y COMMIT DENTRO DEL IF  PARA CONFIRMAR LA LOGICA DE INSERT DE TABLA
        DBMS_OUTPUT.PUT_LINE('TOTAL EMPLEADOS: ' || v_total_emp);
        DBMS_OUTPUT.PUT_LINE('CONFIRMACION: Se insertaron ' || v_contador || ' registros exitosamente');
        COMMIT;
    END IF;
    
END; 
/


