SET serveroutput on;

--======================================
-- EXP 2 SEMANA 4 : CASO 1
--======================================

SAVEPOINT sp_detalle_resumen; 

-- VARIABLE BIND
VAR b_fecha_proceso NUMBER;
EXEC :b_fecha_proceso := EXTRACT(YEAR FROM SYSDATE) - 1; 

-- INICIO BLOQUE PL/SQL
DECLARE

-- VARIABLE FECHA PROCESO CON USO DE VARIABLE BIND
v_annio_proceso NUMBER := :b_fecha_proceso; 

-- VARRAY PUNTOS MULTIPLICADORES CADA 100.000
TYPE t_puntos_tarjeta IS VARRAY(4) OF NUMBER;
va_puntos_tarjeta t_puntos_tarjeta := t_puntos_tarjeta(250, 300, 550, 700);

-- VARRAY RANGO DE VALORES
TYPE t_monto_rango IS VARRAY(3) OF NUMBER;
va_rango t_puntos_tarjeta := t_puntos_tarjeta(500000, 700000, 900000);
  
CURSOR cur_transacciones IS
        SELECT
            c.numrun,
            c.dvrun,
            tc.nro_tarjeta,
            ttc.nro_transaccion,
            ttc.fecha_transaccion,
            ttt.nombre_tptran_tarjeta,
            ttc.monto_transaccion,
            c.cod_tipo_cliente,
            -- CALCULA LA SUMA DE LAS TRANSACCIONES AGRUPANDO POR NUM TARJETA Y CODIGO TARJETA
            SUM(ttc.monto_transaccion)OVER (PARTITION BY tc.nro_tarjeta, ttc.cod_tptran_tarjeta) AS monto_total_tipo
        FROM cliente c
        INNER JOIN tarjeta_cliente tc ON tc.numrun = c.numrun
        INNER JOIN transaccion_tarjeta_cliente ttc ON ttc.nro_tarjeta = tc.nro_tarjeta
        INNER JOIN tipo_transaccion_tarjeta ttt ON ttt.cod_tptran_tarjeta = ttc.cod_tptran_tarjeta
        INNER JOIN tipo_cliente tcl ON tcl.cod_tipo_cliente = c.cod_tipo_cliente
        WHERE EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_annio_proceso
        ORDER BY ttc.fecha_transaccion, c.numrun, ttc.nro_transaccion    
;

-- RECORD UTILIZADO PARA CURSOR CUR_TRANSACCIONES Y PUNTOS_ALLTHEBEST
TYPE type_registro_trans IS RECORD(
    reg_trans cur_transacciones%ROWTYPE,
    puntos_allthebest detalle_puntos_tarjeta_catb.puntos_allthebest%TYPE 
);

v_reg_trans type_registro_trans; 

-- CURSOR CON USO DE PARAMETRO
CURSOR cur_resumen_mensual_puntos(p_fecha NUMBER) IS
            SELECT
                fecha_transaccion,
                SUM(monto_transaccion) AS monto_transaccion,
                SUM(puntos_allthebest) AS puntos_allthebest,
                tipo_transaccion       
            FROM detalle_puntos_tarjeta_catb
            WHERE EXTRACT(YEAR FROM fecha_transaccion) = p_fecha
            GROUP BY fecha_transaccion, tipo_transaccion
            ORDER BY TO_CHAR(fecha_transaccion, 'MMYYYY'), tipo_transaccion;

-- VARIABLE CONTENEDORA DEL TYPE CURSOR_RESUMEN_MENSUAL    
v_reg_puntos cur_resumen_mensual_puntos%ROWTYPE;

v_mes_periodo VARCHAR2(6);    

v_contador NUMBER := 0; 

BEGIN

    --TRUNCADO TABLE DETALLE_PUNTOS_TARJETA_CATB y RESUMEN_PUNTOS_TARJETA_CATB
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_puntos_tarjeta_catb'; 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE resumen_puntos_tarjeta_catb';
    
    -- ABRE CURSOR CUR_TRANSACCIONES
    OPEN cur_transacciones; 
    
    -- LOOP QUE RECORRE CUR_TRANSACCIONES POR FILA
    LOOP
        FETCH cur_transacciones INTO v_reg_trans.reg_trans;
        EXIT WHEN cur_transacciones%NOTFOUND; 
        
        -- LOGICA PARA PUNTOS_ALLTHEBEST
        v_reg_trans.puntos_allthebest := 
            CASE 
                WHEN v_reg_trans.reg_trans.cod_tipo_cliente IN(10,20)
                    THEN TRUNC(v_reg_trans.reg_trans.monto_transaccion/100000)* va_puntos_tarjeta(1)
                WHEN v_reg_trans.reg_trans.cod_tipo_cliente IN(30,40)
                    THEN 
                        CASE
                            WHEN v_reg_trans.reg_trans.monto_total_tipo BETWEEN va_rango(1) AND va_rango(2)
                                THEN TRUNC(v_reg_trans.reg_trans.monto_transaccion/100000) *(va_puntos_tarjeta(1)+va_puntos_tarjeta(2))
                            WHEN v_reg_trans.reg_trans.monto_total_tipo BETWEEN (va_rango(2) + 1) AND va_rango(3)
                                THEN TRUNC(v_reg_trans.reg_trans.monto_transaccion/100000) *(va_puntos_tarjeta(1)+va_puntos_tarjeta(3))
                            WHEN v_reg_trans.reg_trans.monto_total_tipo >va_rango(3)
                                THEN TRUNC(v_reg_trans.reg_trans.monto_transaccion/100000) *(va_puntos_tarjeta(1)+va_puntos_tarjeta(4))
                        ELSE TRUNC(v_reg_trans.reg_trans.monto_transaccion/100000) *va_puntos_tarjeta(1)        
                        END  
            --END CASE            
            END;
        
        -- INSERT DENTRO DEL LOOP A TABLA DETALLE_PUNTOS_TARJETA_CATB
        INSERT INTO detalle_puntos_tarjeta_catb VALUES(
                                                        v_reg_trans.reg_trans.numrun,
                                                        v_reg_trans.reg_trans.dvrun,
                                                        v_reg_trans.reg_trans.nro_tarjeta,
                                                        v_reg_trans.reg_trans.nro_transaccion,
                                                        v_reg_trans.reg_trans.fecha_transaccion,
                                                        v_reg_trans.reg_trans.nombre_tptran_tarjeta,
                                                        v_reg_trans.reg_trans.monto_transaccion,
                                                        v_reg_trans.puntos_allthebest);
                                                                                                                                                                                   
        v_contador := v_contador + 1;
               
        DBMS_OUTPUT.PUT_LINE('NUMRUN: ' || v_reg_trans.reg_trans.numrun);
        DBMS_OUTPUT.PUT_LINE('DVRUN: ' || v_reg_trans.reg_trans.dvrun);
        DBMS_OUTPUT.PUT_LINE('NUMERO TARJETA: ' || v_reg_trans.reg_trans.nro_tarjeta);
        DBMS_OUTPUT.PUT_LINE('NUMERO TRANSACCION: ' || v_reg_trans.reg_trans.nro_transaccion);
        DBMS_OUTPUT.PUT_LINE('FECHA TRANSACCION: ' || v_reg_trans.reg_trans.fecha_transaccion);
        DBMS_OUTPUT.PUT_LINE('TIPO TRANSACCION: ' || v_reg_trans.reg_trans.nombre_tptran_tarjeta);
        DBMS_OUTPUT.PUT_LINE('MONTO TRANSACCION: ' || v_reg_trans.reg_trans.monto_transaccion);
        DBMS_OUTPUT.PUT_LINE('PUNTOS ALLTTHEBEST: ' || v_reg_trans.puntos_allthebest);
        DBMS_OUTPUT.PUT_LINE('COD TIPO CLIENTE: ' || v_reg_trans.reg_trans.cod_tipo_cliente);      
        DBMS_OUTPUT.PUT_LINE('' );
    
    -- CIERRE LOOP   
    END LOOP;
    
    -- CIERRE CURSOR CUR_TRANSACCIONES
    CLOSE cur_transacciones; 
    
    -- IF CONFIRMACION CON USO DE CONTADOR PARA COMMIT
    IF v_contador >0 THEN
        COMMIT; 
        DBMS_OUTPUT.PUT_LINE('Total de registros efectuados: ' || v_contador);
        
        -- RECICLADO DE VARIABLE V_CONTADOR
        v_contador :=0; 
        
        
        -- INSERT 12(MESES) FILAS POR MEDIO DE FOR EN TABLA RESUMEN_PUNTOS_TARJETA_CATB
        FOR i IN 1..12 LOOP
        INSERT INTO resumen_puntos_tarjeta_catb
        VALUES (LPAD(TO_CHAR(i), 2, '0') || TO_CHAR(v_annio_proceso),0, 0, 0, 0, 0, 0);
        
        v_contador := v_contador +1; 
        
        -- CIERRE CICLO FOR
        END LOOP;
        
        -- CONFIRMACION CON USO DE CONTADOR
        IF v_contador >0 THEN
            COMMIT;
            
            -- LUEGO DE INSERTAR LAS FILAS RESPETANDO LA PK DE LA TABLA RESUMEN_PUNTOS_TARJETA_CATB SE REALIZA EL UPDATE
            -- ABRE CURSOR CON PARAMETRO
            OPEN cur_resumen_mensual_puntos(v_annio_proceso);
            
            -- INICIO LOOP
            LOOP
                FETCH cur_resumen_mensual_puntos INTO v_reg_puntos;
                EXIT WHEN cur_resumen_mensual_puntos%NOTFOUND;
                
                v_mes_periodo := TO_CHAR(v_reg_puntos.fecha_transaccion, 'MMYYYY');
                
                -- UPDATE SUMANDO VALORES SEGUN TIPO
                UPDATE resumen_puntos_tarjeta_catb
                SET 
                    monto_total_compras = 
                        monto_total_compras + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'Compras Tiendas Retail o Asociadas' 
                                    THEN v_reg_puntos.monto_transaccion 
                                ELSE 0 
                            END,
                    total_puntos_compras = 
                        total_puntos_compras + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'Compras Tiendas Retail o Asociadas' 
                                    THEN v_reg_puntos.puntos_allthebest 
                                ELSE 0 
                            END,
                    monto_total_avances = 
                        monto_total_avances + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'Avance en Efectivo' 
                                    THEN v_reg_puntos.monto_transaccion 
                                ELSE 0 
                            END,
                    total_puntos_avances = 
                        total_puntos_avances + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'Avance en Efectivo' 
                                    THEN v_reg_puntos.puntos_allthebest 
                                ELSE 0 
                            END,
                    monto_total_savances = 
                        monto_total_savances + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'S�per Avance en Efectivo' 
                                    THEN v_reg_puntos.monto_transaccion 
                                ELSE 0 
                            END,
                    total_puntos_savances = 
                        total_puntos_savances + 
                            CASE 
                                WHEN v_reg_puntos.tipo_transaccion = 'S�per Avance en Efectivo' 
                                    THEN v_reg_puntos.puntos_allthebest 
                                ELSE 0 
                            END
                WHERE mes_anno = v_mes_periodo;
            
            -- CIERRE LOOP   
            END LOOP;
            
            -- CIERRE CURSOR
            CLOSE cur_resumen_mensual_puntos;
            
            IF SQL%ROWCOUNT > 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('UPDATES COMPLETOS');
                
                -- ELIMINAR LAS FILAS QUE ESTAN EN 0
                DELETE FROM resumen_puntos_tarjeta_catb
                WHERE monto_total_compras = 0 
                AND total_puntos_compras = 0
                AND monto_total_avances = 0
                AND total_puntos_avances = 0
                AND monto_total_savances = 0
                AND total_puntos_savances = 0;
            
                COMMIT;   
                DBMS_OUTPUT.PUT_LINE('Proceso completado exitosamente');
                
            ELSE 
                ROLLBACK TO SAVEPOINT sp_detalle_resumen ;
                DBMS_OUTPUT.PUT_LINE('ERROR EN LA EJECUCION SE HA RETORNADO AL SAVEPOINT');
            END IF; 
            
                      
        ELSE 
            ROLLBACK TO SAVEPOINT sp_detalle_resumen ;
            DBMS_OUTPUT.PUT_LINE('ERROR EN LA EJECUCION SE HA RETORNADO AL SAVEPOINT');
        END IF; 
                         
    ELSE
        ROLLBACK TO SAVEPOINT sp_detalle_resumen ; 
        DBMS_OUTPUT.PUT_LINE('ERROR EN LA EJECUCION SE HA RETORNADO AL SAVEPOINT');
    END IF; 
    
END;
/
    

--======================================
-- EXP 2 SEMANA 4 : CASO 2
--======================================

SAVEPOINT sp_aporte_sbif_1; 

-- VARIABLE BIND AÑO PROCESO
VAR b_anno_proceso_sbif NUMBER;
EXEC :b_anno_proceso_sbif := EXTRACT(YEAR FROM SYSDATE); 

DECLARE

v_anno_proceso NUMBER := :b_anno_proceso_sbif;  

-- VARRAY QUE GUARDA LOS PORCENTAJES CON LOS QUE SE CALCULA EL APORTE
TYPE t_tramo_porcentaje IS VARRAY(5) OF NUMBER;
va_tramo_porcentaje t_tramo_porcentaje := t_tramo_porcentaje(0.01,0.02, 0.03, 0.04, 0.07); 

-- TRAMOS CON LOS QUE SE CALCULA EL PORCENTAJE
TYPE t_tramo_aporte IS VARRAY(6) OF NUMBER;
va_tramo_aporte t_tramo_aporte := t_tramo_aporte(30000,100000,200000, 400000, 600000, 10000000);  

v_contador NUMBER := 0;
v_monto NUMBER; 

-- CURSOR CON PARAMETRO
CURSOR cur_aporte_sbif(p_anno_proceso NUMBER) IS
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
    AND ttt.cod_tptran_tarjeta IN(102,103)
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

-- CAST DE TYPE A VARIABLE DE USO    
v_reg_aporte type_registro_aporte; 

BEGIN
    -- TRUNCATE DE TABLAS: detalle_aporte_sbif, resumen_aporte_sbif
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_aporte_sbif';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE resumen_aporte_sbif';
    
    -- ABRE CURSOR CON PARAMETRO
    OPEN cur_aporte_sbif(v_anno_proceso);
    
    -- INICIO LOOP
    LOOP
        FETCH cur_aporte_sbif INTO v_reg_aporte.reg_aporte; 
        EXIT WHEN cur_aporte_sbif%NOTFOUND;
        
        v_monto := v_reg_aporte.reg_aporte.monto_total_transaccion; 
        
        -- LOGICA APORTE
        v_reg_aporte.aporte :=
            CASE
                WHEN v_monto BETWEEN va_tramo_aporte(1) AND va_tramo_aporte(2) THEN v_monto * va_tramo_porcentaje(1)
                WHEN v_monto BETWEEN (va_tramo_aporte(2) +1) AND va_tramo_aporte(3) THEN v_monto * va_tramo_porcentaje(2)
                WHEN v_monto BETWEEN (va_tramo_aporte(3) +1) AND va_tramo_aporte(4) THEN v_monto * va_tramo_porcentaje(3)
                WHEN v_monto BETWEEN (va_tramo_aporte(4) +1) AND va_tramo_aporte(5) THEN v_monto * va_tramo_porcentaje(4)
                WHEN v_monto BETWEEN (va_tramo_aporte(5) +1) AND va_tramo_aporte(6) THEN v_monto * va_tramo_porcentaje(5)
                    
            END; 
        
        v_contador := v_contador +1; 
        
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
    -- CIERRE LOOP                   
    END LOOP;
    
    -- CIERRE CURSOR
    CLOSE cur_aporte_sbif;
    
    -- CONFIRMACION CON USO DE CONTADOR Y COMMIT
    IF v_contador > 0 THEN
        COMMIT;
        
        SAVEPOINT sp_aporte_sbif_2; 
        
        -- RECICLADO VARIABLE CONTADOR
        v_contador := 0; 
        
        DBMS_OUTPUT.PUT_LINE('FILA INGRESADAS EN TABLA DETALLE_APORTE_SBID: ' || v_contador);
        DBMS_OUTPUT.PUT_LINE('-----');
        
        -- OPEN CURSOR RESUMEN
        OPEN cur_aporte_resumen; 
        
        -- LOOP CURSOR CUR_APORTE_RESUMEN
        LOOP
            FETCH cur_aporte_resumen INTO v_reg_aporte.reg_resumen; 
            EXIT WHEN cur_aporte_resumen%NOTFOUND;
            
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
                                                    
            v_contador := v_contador + 1; 
            
            -- CONFIRMACION CON USO DE CONTADOR Y COMMIT
            IF v_contador > 0 THEN
                COMMIT; 
                
                DBMS_OUTPUT.PUT_LINE('FILA INGRESADAS EN TABLA RESUMEN_APORTE_SBID: ' || v_contador);
            ELSE
                ROLLBACK TO SAVEPOINT sp_aporte_sbif_2;
                
            END IF; 
            
        -- CIERRE DE LOOP    
        END LOOP; 
        
        -- CIERRE CURSOR
        CLOSE cur_aporte_resumen;       
        
    ELSE
        ROLLBACK TO SAVEPOINT sp_aporte_sbif_1;
        DBMS_OUTPUT.PUT_LINE('ERROR AL INGRESAR FILAS EN TABLA DETALLE_APORTE_SBID');
    END IF; 
       
END;





