--CASO 1:

--Almacenar informacion en la tabla CLIENTE_TODOSUMA

SET serveroutput on; 

-- Variable BIND
DEFINE b_numrun_usuario = 22558061;  

-- BLOQUE PL/SQL 

DECLARE
v_numrun_usuario1 NUMBER(8):= &b_numrun_usuario;

--Variables para almacenar los valores que obtenemos del select
--Se obtienen los tipos de forma %TYPE desde la columna de la tabla cliente_todosuma
v_nro_cliente cliente_todosuma.nro_cliente%type; 
v_run_cliente cliente_todosuma.run_cliente%type; 
v_nombre_cliente cliente_todosuma.nombre_cliente%type; 
v_tipo_cliente cliente_todosuma.tipo_cliente%type;
v_monto_solic_credito cliente_todosuma.monto_solic_creditos%type;
v_monto_pesos_ts cliente_todosuma.monto_pesos_todosuma%type; 

--Variables de Rangos Total Credito Solicitado
v_trab_indep_rango1 NUMBER := 1000000;
v_trab_indep_rango2 NUMBER := 3000000; 

v_todosuma_base NUMBER := 1200;
v_todosuma_ind_r1 NUMBER := 100;
v_todosuma_ind_r2 NUMBER := 300;  
v_todosuma_ind_r3 NUMBER := 550;   

BEGIN
    SELECT 
        c.nro_cliente,
        TO_CHAR(c.numrun, '999G999G999') || '-' || c.dvrun,
        c.pnombre || ' ' || c.snombre || ' ' || c.appaterno || ' ' || c.apmaterno,
        tc.nombre_tipo_cliente, 
        SUM(cc.monto_solicitado)
    INTO v_nro_cliente, v_run_cliente, v_nombre_cliente, v_tipo_cliente, v_monto_solic_credito 
    FROM cliente c
    INNER JOIN tipo_cliente tc ON tc.cod_tipo_cliente = c.cod_tipo_cliente
    INNER JOIN credito_cliente cc ON cc.nro_cliente = c.nro_cliente
    WHERE EXTRACT(YEAR FROM cc.fecha_solic_cred) = EXTRACT(YEAR FROM SYSDATE) - 1
    AND numrun = v_numrun_usuario1
    GROUP BY
        c.nro_cliente,
        c.numrun,
        c.dvrun,
        c.pnombre,
        c.snombre,
        c.appaterno,
        c.apmaterno,
        tc.nombre_tipo_cliente
    ; 
    -- IF para segmentar el tipo de trabajador 
    IF v_tipo_cliente = 'Trabajadores independientes' THEN 
            -- IF para los segmentar los Pesos Extras dentro de "Trabajadores independientes"    
            IF v_monto_solic_credito < v_trab_indep_rango1
                THEN v_monto_pesos_ts :=  TRUNC(v_monto_solic_credito/100000) * (v_todosuma_base + v_todosuma_ind_r1);
            ELSIF v_monto_solic_credito BETWEEN v_trab_indep_rango1 AND v_trab_indep_rango2  
                THEN v_monto_pesos_ts :=  TRUNC(v_monto_solic_credito/100000) * (v_todosuma_base + v_todosuma_ind_r2);
            ELSIF v_monto_solic_credito > v_trab_indep_rango2  
                THEN v_monto_pesos_ts :=  TRUNC(v_monto_solic_credito/100000) * (v_todosuma_base + v_todosuma_ind_r3); 
            END IF;
    ELSE v_monto_pesos_ts :=  TRUNC(v_monto_solic_credito/100000) * v_todosuma_base;        
    END IF
    ;
    
    --Insert de valores en la tabla CLIENTE_TODOSUMA
    INSERT INTO cliente_todosuma (nro_cliente, run_cliente, nombre_cliente, tipo_cliente, monto_solic_creditos, monto_pesos_todosuma)
    VALUES (v_nro_cliente, v_run_cliente, v_nombre_cliente, v_tipo_cliente,  v_monto_solic_credito,  v_monto_pesos_ts);
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('NUMERO CLIENTE: ' || v_nro_cliente);
    DBMS_OUTPUT.PUT_LINE('RUT: ' || v_run_cliente);
    DBMS_OUTPUT.PUT_LINE('NOMBRE CLIENTE: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('TIPO CLIENTE: ' || v_tipo_cliente);
    DBMS_OUTPUT.PUT_LINE('TOTAL CREDITO SOLICITADO CLIENTE: ' || v_monto_solic_credito);
    DBMS_OUTPUT.PUT_LINE('TOTAL PESOS TODOSUMA CLIENTE: ' || v_monto_pesos_ts);
END;
/

-- CASO 2:

--SELECT inicial. Permite obtener la ultima cuota del numero de solicitud de credito
/*
SELECT * 
FROM cuota_credito_cliente ccc
INNER JOIN credito_cliente cc ON cc.nro_solic_credito = ccc.nro_solic_credito
INNER JOIN cliente c ON c.nro_cliente = cc.nro_cliente
WHERE ccc.nro_solic_credito = 3004
ORDER BY ccc.nro_cuota DESC
FETCH FIRST 1 ROW ONLY
;
*/


-- BLOQUE PL/SQL
/*
-- Crear tabla de prueba con la misma estructura que cuota_credito_cliente
CREATE TABLE cuota_credito_cliente_prueba AS
SELECT * FROM cuota_credito_cliente
WHERE 1=0;
*/

--DROP TABLE cuota_credito_cliente_prueba
--SELECT * FROM cuota_credito_cliente_prueba; 

--SELECT * FROM cuota_credito_cliente
--WHERE nro_solic_credito = 2001

--Insertamos valor de pueba
--INSERT INTO cuota_credito_cliente_prueba (nro_solic_credito, nro_cuota, fecha_venc_cuota, valor_cuota) VALUES(3004, 36 , '01/12/28', 105555); 

-- Variables BIND
DEFINE b_num_solic_credito = 2001; 

DEFINE b_cantidad_cuotas_postergar = 2;   
DECLARE

--Variables caso planteado: Nº Solicitud credito y Cantidad de Cuotas 
v_num_solic_credito NUMBER(10) := &b_num_solic_credito;
v_cantidad_cuotas_postergar NUMBER(1) := &b_cantidad_cuotas_postergar;  

v_nro_ultima_cuota_cred NUMBER(3);
v_num_cliente NUMBER(3);
v_nombre_cliente VARCHAR2(25);
v_numero_creditos NUMBER(1);
v_valor_cuota NUMBER(10);
v_fecha_ultima_cuota DATE; 
v_codigo_credito NUMBER(1);
v_interes_nuevas_cuotas NUMBER(5,3); 

BEGIN
    SELECT ccc.nro_cuota, cc.nro_cliente, c.pnombre || ' ' || c.appaterno, ccc.valor_cuota, ccc.fecha_venc_cuota, cc.cod_credito
    INTO v_nro_ultima_cuota_cred, v_num_cliente, v_nombre_cliente, v_valor_cuota, v_fecha_ultima_cuota, v_codigo_credito      
    FROM cuota_credito_cliente ccc
    INNER JOIN credito_cliente cc ON cc.nro_solic_credito = ccc.nro_solic_credito
    INNER JOIN cliente c ON c.nro_cliente = cc.nro_cliente
    WHERE ccc.nro_solic_credito = v_num_solic_credito
    ORDER BY ccc.nro_cuota DESC
    FETCH FIRST 1 ROW ONLY  
;
    -- SELECT PARA OBTENER EL NUMERO DE CREDITOS DEL AÑO ANTERIOR
    SELECT COUNT(DISTINCT nro_solic_credito)
    INTO v_numero_creditos
    FROM credito_cliente
    WHERE nro_cliente = v_num_cliente AND EXTRACT(YEAR FROM fecha_solic_cred) = EXTRACT(YEAR FROM SYSDATE) -1 
;
    -- IF PARA SEGMENTAR EL VALOR DEL INTERES DE LAS NUEVAS CUOTAS SOLICITADAS 
    IF v_codigo_credito = 1 THEN
    
        -- IF QUE CONSIDERA LA CANTIDAD DE CUOTAS A POSTERGAR PARA EL COD CREDITO 1
        IF v_cantidad_cuotas_postergar =1 THEN v_interes_nuevas_cuotas := 1;
        ELSIF v_cantidad_cuotas_postergar =2 THEN v_interes_nuevas_cuotas := 1.005;
        END IF;  
    ELSIF v_codigo_credito = 2 THEN v_interes_nuevas_cuotas := 1.01;
    ELSIF v_codigo_credito = 3 THEN v_interes_nuevas_cuotas := 1.02;    
    END IF
;
    -- IF PARA CONSIDERAR EL NUMERO DE CREDITOS DEL AÑO ANTERIOR
    IF v_numero_creditos = 1 THEN
    
        -- LOOP FOR PARA INSERTAR LOS VALORES EN LA TABLA CUOTA_CREDITO_CLIENTE
        FOR i IN 1..v_cantidad_cuotas_postergar LOOP    
            v_nro_ultima_cuota_cred := v_nro_ultima_cuota_cred +1; 
            v_fecha_ultima_cuota := ADD_MONTHS(v_fecha_ultima_cuota, 1); 
            
            INSERT INTO cuota_credito_cliente(nro_solic_credito, nro_cuota, fecha_venc_cuota, valor_cuota)
            VALUES(v_num_solic_credito, v_nro_ultima_cuota_cred , v_fecha_ultima_cuota, v_valor_cuota * v_interes_nuevas_cuotas); 
        END LOOP;    
     
     --NUMERO DE CREDITOS MAYORES A 1   
     ELSIF v_numero_creditos > 1 THEN
     
        -- EN EL CASO DE QUE EL NUMERO DE CREDITOS SEA MAYOR A 1 SE DEBE ACTUALIZAR LA ULTIMA CUOTA DEL CREDITO
        UPDATE cuota_credito_cliente
        SET fecha_pago_cuota = v_fecha_ultima_cuota, monto_pagado = v_valor_cuota
        WHERE nro_cuota = v_nro_ultima_cuota_cred;   
        
        --FOR PARA INSERTAR NUEVAS CUOTAS A TABLA CUOTA_CREDITO_CLIENTE
        FOR i IN 1..v_cantidad_cuotas_postergar LOOP       
            v_nro_ultima_cuota_cred := v_nro_ultima_cuota_cred +1; 
            v_fecha_ultima_cuota := ADD_MONTHS(v_fecha_ultima_cuota, 1); 
            
            INSERT INTO cuota_credito_cliente(nro_solic_credito, nro_cuota, fecha_venc_cuota, valor_cuota)
            VALUES(v_num_solic_credito, v_nro_ultima_cuota_cred , v_fecha_ultima_cuota, v_valor_cuota * v_interes_nuevas_cuotas); 
        END LOOP;
     END IF   
;
    COMMIT
;    
    DBMS_OUTPUT.PUT_LINE('NUMERO CLIENTE: ' || v_num_cliente);
    DBMS_OUTPUT.PUT_LINE('NOMBRE CLIENTE: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('TOTAL CREDITOS: ' || v_numero_creditos);
    DBMS_OUTPUT.PUT_LINE('CODIGO CREDITO: ' || v_codigo_credito);
    DBMS_OUTPUT.PUT_LINE('VALOR CUOTA: ' || v_valor_cuota);
    DBMS_OUTPUT.PUT_LINE('INTERES NUEVAS CUOTA: ' || v_interes_nuevas_cuotas);
    DBMS_OUTPUT.PUT_LINE('FECHA ULTIMA CUOTA: ' || v_fecha_ultima_cuota);
    DBMS_OUTPUT.PUT_LINE('La ultima cuota del credito ' || v_num_solic_credito || ' es: ' ||  v_nro_ultima_cuota_cred );

END
; 
/
