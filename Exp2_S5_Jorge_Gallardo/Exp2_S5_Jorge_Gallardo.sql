--======================================
-- EXP 2 SEMANA 4 : CASO 2
--======================================

-- CREAR TABLA PARA ALMACENAR LISTA DE ERRORES
/*
-- Tabla para registrar ERRORES
CREATE TABLE error_log (
  id_log    NUMBER GENERATED ALWAYS AS IDENTITY,
  fecha_log DATE DEFAULT SYSDATE NOT NULL,
  cod_error NUMBER,
  msg_error VARCHAR2(200)
);

*/

SET serveroutput on;

-- VARIABLE BIND AÑO PROCESO Y TIPO TARJETA
VAR b_anno_proceso_sbif NUMBER;
VAR b_tipo_tarjeta_1 NUMBER; 
VAR b_tipo_tarjeta_2 NUMBER; 

EXEC :b_anno_proceso_sbif := EXTRACT(YEAR FROM SYSDATE); 
EXEC :b_tipo_tarjeta_1 := 102;
EXEC :b_tipo_tarjeta_2 := 103; 

DECLARE

-- VARIABLES QUE RECIBEN EL VALOR DE LAS VARIABLES BIND
v_anno_proceso NUMBER := :b_anno_proceso_sbif; 
v_tipo_tarjeta_1 NUMBER := :b_tipo_tarjeta_1;
v_tipo_tarjeta_2 NUMBER := :b_tipo_tarjeta_2;

-- VARRAY QUE GUARDA LOS PORCENTAJES CON LOS QUE SE CALCULA EL APORTE
TYPE t_tramo_porcentaje IS VARRAY(5) OF NUMBER;
va_tramo_porcentaje t_tramo_porcentaje := t_tramo_porcentaje(0.01,0.02, 0.03, 0.04, 0.07); 

-- TRAMOS CON LOS QUE SE CALCULA EL PORCENTAJE
TYPE t_tramo_aporte IS VARRAY(6) OF NUMBER;
va_tramo_aporte t_tramo_aporte := t_tramo_aporte(30000,100000,200000, 400000, 600000, 10000000);  

-- VARIABLE CONTADOR DENTRO DE LOS CICLOS DE CURSOR
v_contador NUMBER := 0;

v_monto NUMBER; 

-- VARIABLES PARA REGISTRAR ERRORES CODIGO Y MENSAJE
v_cod_error NUMBER;
v_msg_error VARCHAR2(200);

-- DECLARACION DE VARIABLE EXCEPTION DEFINIDA POR EL USUARIO
e_monto_invalido EXCEPTION;

-- DECLARACION DE VARIABLE EXCEPTION NO PREDEFINIDA (ORA-01400)
e_not_null EXCEPTION;
PRAGMA EXCEPTION_INIT(e_not_null, -1400);

-- CURSOR CON PARAMETRO
CURSOR cur_aporte_sbif(p_anno_proceso NUMBER, p_tipo_tarjeta_1 NUMBER, p_tipo_tarjeta_2 NUMBER) IS
    SELECT
        tc.numrun,
        c.dvrun,
        tc.nro_tarjeta,
        ttc.nro_transaccion,
        ttc.fecha_transaccion,
        ttt.cod_tptran_tarjeta,
        ttt.nombre_tptran_tarjeta,
        ttc.monto_total_transaccion  
    FROM tarjeta_cliente tc
    INNER JOIN cliente c ON c.numrun = tc.numrun
    INNER JOIN transaccion_tarjeta_cliente ttc ON ttc.nro_tarjeta = tc.nro_tarjeta
    INNER JOIN tipo_transaccion_tarjeta ttt ON ttt.cod_tptran_tarjeta = ttc.cod_tptran_tarjeta
    WHERE EXTRACT(YEAR FROM fecha_transaccion) = p_anno_proceso
    AND ttt.cod_tptran_tarjeta IN(p_tipo_tarjeta_1,p_tipo_tarjeta_2)
    ORDER BY ttc.fecha_transaccion,tc.numrun
;

CURSOR cur_aporte_resumen IS
    SELECT
        TO_CHAR(fecha_transaccion, 'MMYYYY') AS mes_anno,
        tipo_transaccion,
        SUM(monto_transaccion) AS suma_monto,
        SUM(aporte_sbif) AS suma_aporte
    FROM detalle_aporte_sbif
    GROUP BY TO_CHAR(fecha_transaccion, 'MMYYYY'), tipo_transaccion
    ORDER BY mes_anno, tipo_transaccion;
    
-- REGISTRO QUE ENCAPSULA AMBOS CURSORES:  cur_aporte_sbif, cur_aporte_resumen
TYPE type_registro_aporte IS RECORD(
    reg_aporte cur_aporte_sbif%ROWTYPE,
    reg_resumen cur_aporte_resumen%ROWTYPE,
    aporte detalle_aporte_sbif.aporte_sbif%TYPE 
    ); 

-- CAST DE TYPE A VARIABLE    
v_reg_aporte type_registro_aporte; 

BEGIN
    -- TRUNCATE DE TABLAS: detalle_aporte_sbif, resumen_aporte_sbif, error_log
    EXECUTE IMMEDIATE 'TRUNCATE TABLE error_log'; 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_aporte_sbif'; 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE resumen_aporte_sbif'; 
    
    -- USO DE IF PARA OPEN CURSOR CON PARAMETROS PARA TRABAJO CON TABLA detalle_aporte_sbif
    IF NOT cur_aporte_sbif%ISOPEN THEN
        OPEN cur_aporte_sbif(v_anno_proceso, v_tipo_tarjeta_1, v_tipo_tarjeta_2);
    END IF;      
    
    LOOP
        -- FETCH DEVUELVE FILA POR FILA LOS DATOS DEL CURSOR
        FETCH cur_aporte_sbif INTO v_reg_aporte.reg_aporte; 
        EXIT WHEN cur_aporte_sbif%NOTFOUND; 
    
        -- INICIO BLOQUE ANIDADO   
        BEGIN 
        
            v_monto := v_reg_aporte.reg_aporte.monto_total_transaccion; 
            
            -- IF PARA RAISE EXCEPTION DEFINIDA POR EL USUARIO
            IF v_monto <= 0 THEN 
                RAISE e_monto_invalido; 
            END IF; 
            
            -- LOGICA APORTE
            v_reg_aporte.aporte :=
                CASE
                    WHEN v_monto BETWEEN va_tramo_aporte(1) AND va_tramo_aporte(2) THEN v_monto * va_tramo_porcentaje(1)
                    WHEN v_monto BETWEEN (va_tramo_aporte(2) +1) AND va_tramo_aporte(3) THEN v_monto * va_tramo_porcentaje(2)
                    WHEN v_monto BETWEEN (va_tramo_aporte(3) +1) AND va_tramo_aporte(4) THEN v_monto * va_tramo_porcentaje(3)
                    WHEN v_monto BETWEEN (va_tramo_aporte(4) +1) AND va_tramo_aporte(5) THEN v_monto * va_tramo_porcentaje(4)
                    WHEN v_monto BETWEEN (va_tramo_aporte(5) +1) AND va_tramo_aporte(6) THEN v_monto * va_tramo_porcentaje(5)
                        
                END; 
             
            
            DBMS_OUTPUT.PUT_LINE('NUMRUN: ' || v_reg_aporte.reg_aporte.numrun);
            DBMS_OUTPUT.PUT_LINE('DVRUN: ' || v_reg_aporte.reg_aporte.dvrun);
            DBMS_OUTPUT.PUT_LINE('NUMERO TARJETA: ' || v_reg_aporte.reg_aporte.nro_tarjeta);
            DBMS_OUTPUT.PUT_LINE('NUMERO TARJETA: ' || v_reg_aporte.reg_aporte.nro_transaccion);
            DBMS_OUTPUT.PUT_LINE('FECHA TRANSACCION: ' || v_reg_aporte.reg_aporte.fecha_transaccion);
            DBMS_OUTPUT.PUT_LINE('TIPO TRANSACCION: ' || v_reg_aporte.reg_aporte.nombre_tptran_tarjeta);
            DBMS_OUTPUT.PUT_LINE('MONTO TOTAL TRANSACCION: ' || v_reg_aporte.reg_aporte.monto_total_transaccion);
            DBMS_OUTPUT.PUT_LINE('MONTO TOTAL APORTE: ' || v_reg_aporte.aporte);
            DBMS_OUTPUT.PUT_LINE('');
            
            -- INSERT EN TABLA DETALLE_APORTE_SBIF
            INSERT INTO detalle_aporte_sbif VALUES(v_reg_aporte.reg_aporte.numrun,
                                                    v_reg_aporte.reg_aporte.dvrun,
                                                    v_reg_aporte.reg_aporte.nro_tarjeta,
                                                    v_reg_aporte.reg_aporte.nro_transaccion,
                                                    v_reg_aporte.reg_aporte.fecha_transaccion,
                                                    v_reg_aporte.reg_aporte.nombre_tptran_tarjeta,
                                                    v_reg_aporte.reg_aporte.monto_total_transaccion,
                                                    v_reg_aporte.aporte); 
                                                    
            IF SQL%ROWCOUNT =1 THEN    
                v_contador := v_contador +1;
            END IF; 
            
        EXCEPTION 
            -- EXCEPTION CREADA POR EL USUARIO
            WHEN e_monto_invalido THEN 
                v_cod_error := -20001;
                v_msg_error := 'Monto inválido: debe ser > 0';
                
                INSERT INTO error_log(fecha_log, cod_error, msg_error) 
                VALUES (SYSDATE, v_cod_error, v_msg_error);
                
                DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
                
            WHEN e_not_null THEN
                v_cod_error := SQLCODE;
                v_msg_error := SQLERRM;

                INSERT INTO error_log(fecha_log, cod_error, msg_error)
                VALUES (SYSDATE, v_cod_error, v_msg_error);
                
                DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
                
            WHEN OTHERS THEN
                v_cod_error := SQLCODE;
                v_msg_error := SQLERRM;

                INSERT INTO error_log(fecha_log, cod_error, msg_error)
                VALUES (SYSDATE, v_cod_error, v_msg_error);
                
                DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
                
        -- CIERRE BLOQUE ANIDADO
        END; 
        
    -- CIERRE LOOP CURSOR    
    END LOOP;
    
    -- CIERRE CURSOR
    CLOSE cur_aporte_sbif;
    
    -- CONFIRMACION CON COMMIT
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('FILA INGRESADAS EN TABLA DETALLE_APORTE_SBID: ' || v_contador);
    DBMS_OUTPUT.PUT_LINE('-----');

    --TRABAJO CON TABLA resumen_aporte_sbif
    
    -- RECICLADO VARIABLE CONTADOR
    v_contador := 0; 
    
    -- OPEN CURSOR RESUMEN
    OPEN cur_aporte_resumen; 
        
    -- LOOP CURSOR CUR_APORTE_RESUMEN
    LOOP
        FETCH cur_aporte_resumen INTO v_reg_aporte.reg_resumen; 
        EXIT WHEN cur_aporte_resumen%NOTFOUND;
        
        -- ABRE BLOQUE ANIDADO
        BEGIN 
            
            DBMS_OUTPUT.PUT_LINE('MES AÑO: ' || v_reg_aporte.reg_resumen.mes_anno);
            DBMS_OUTPUT.PUT_LINE('TIPO TRANSACCION: ' || v_reg_aporte.reg_resumen.tipo_transaccion);
            DBMS_OUTPUT.PUT_LINE('TOTAL TRANSACCIONES: ' || v_reg_aporte.reg_resumen.suma_monto);
            DBMS_OUTPUT.PUT_LINE('TOTAL APORTE: ' || v_reg_aporte.reg_resumen.suma_aporte);
            DBMS_OUTPUT.PUT_LINE('');
                
            -- INSERT DE VALORES EN TABLA RESUMEN_APORTE_SBIF
            INSERT INTO resumen_aporte_sbif VALUES(v_reg_aporte.reg_resumen.mes_anno,
                                                   v_reg_aporte.reg_resumen.tipo_transaccion,
                                                   v_reg_aporte.reg_resumen.suma_monto,
                                                   v_reg_aporte.reg_resumen.suma_aporte);
                                                    
            IF SQL%ROWCOUNT =1 THEN    
                v_contador := v_contador +1;
            END IF;  
            
            EXCEPTION
                
                WHEN OTHERS THEN
                    v_cod_error := SQLCODE;
                    v_msg_error := SQLERRM;

                    INSERT INTO error_log(fecha_log, cod_error, msg_error)
                    VALUES (SYSDATE, v_cod_error, v_msg_error);  
                    
                    DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
        
        -- CIERRE BLOQUE ANIDADO    
        END;      
        
        DBMS_OUTPUT.PUT_LINE('FILA INGRESADAS EN TABLA RESUMEN_APORTE_SBID: ' || v_contador);
                       
    -- CIERRE DE LOOP    
    END LOOP; 
    
    -- CONFIRMACION CON COMMIT
    COMMIT;
        
    -- CIERRE CURSOR
    CLOSE cur_aporte_resumen;
    
    EXCEPTION
        -- EXCEPTIONS DEFINIDAS POR ORACLE
        WHEN NO_DATA_FOUND THEN
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error);  
                    
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
        
        WHEN STORAGE_ERROR THEN
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error);  
                    
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
        
        WHEN OTHERS THEN 
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error);  
                    
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_cod_error || ', MENSAJE: ' || v_msg_error);
                
END;
/
