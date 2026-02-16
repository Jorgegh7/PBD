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

-- PROCEDIMIENTO QUE ALMACENA EN UN CURSOR DINAMICO, QUE ES UN PARAMETRO DE SALIDA,
-- LA LISTA DE DEPARTAMENTOS CON NO PAGO DURANTE 2 MESES ENTREGADOS COMO PARAMETROS DE ENTRADA
-- EN CADA FILA DEL CURSOR SE ALMACENA EL NUMERO DE PAGOS EFECTUADOS (0,1)
-- ESTE VALOR QUE SE UTILIZA EN EL SP sp_ins_dptos_nopago PARA EL CALCULO DE LAS MULTAS, OBSERVACIONES, INPUT Y UPDATE

CREATE OR REPLACE PROCEDURE sp_dptos_nopago_2meses(
    p_mes1   NUMBER,
    p_mes2   NUMBER,
    p_cursor OUT SYS_REFCURSOR -- PARAMETRO DE SALIDA CURSOR DINAMICO
) 
IS
-- VARIABLES PARA REGISTRAR ERRORES CODIGO Y MENSAJE
v_cod_error NUMBER;
v_msg_error VARCHAR2(200);

BEGIN 
    --ABRE CURSOR DINAMICO
    OPEN p_cursor FOR
        SELECT
            e.nombre_edif,
            d.id_edif,
            d.nro_depto, 
            CASE 
              WHEN COUNT(DISTINCT pgc.anno_mes_pcgc) = 0 THEN 0  -- 0 pagos durante los 2 meses
              WHEN COUNT(DISTINCT pgc.anno_mes_pcgc) = 1 THEN 1  -- 1 pago durante los 2 meses
            END AS numero_pagos
        FROM departamento d
        JOIN edificio e ON e.id_edif = d.id_edif
        -- LEFT JOIN PARA INCLUIR DEPARTAMENTOS QUE NO ESTAN EN LA TABLA pago_gasto_comun
        LEFT JOIN pago_gasto_comun pgc ON pgc.id_edif = d.id_edif AND pgc.nro_depto = d.nro_depto AND pgc.anno_mes_pcgc IN (p_mes1, p_mes2)
        GROUP BY e.nombre_edif, d.id_edif, d.nro_depto
        HAVING COUNT(DISTINCT pgc.anno_mes_pcgc) < 2   -- faltó en al menos un mes
        ORDER BY e.nombre_edif, d.nro_depto;
        
        EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error); 
            COMMIT; 
            
        WHEN OTHERS THEN    
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error);  
            COMMIT; 
    
END;

--================================================================================================

-- PROCEDIMIENTO QUE REALIZA INSERT SOBRE LA TABLA gasto_comun_pago_cero Y UPDATE SOBRE gasto_comun
CREATE OR REPLACE PROCEDURE sp_ins_dptos_nopago(
    p_anno_mes_proceso NUMBER,
    p_id_edif NUMBER,
    p_nro_depto NUMBER,
    p_valor_uf NUMBER,
    p_observacion_1 VARCHAR2,
    p_observacion_2 VARCHAR2,
    p_numero_pagos NUMBER  --parámetro que entrega el numero de pagos durante los ultimos 2 meses (0,1)
)
IS

v_gcpc gasto_comun_pago_cero%ROWTYPE; 
v_fecha_final_pago DATE; 

-- VARIABLES PARA REGISTRAR ERRORES CODIGO Y MENSAJE
v_cod_error NUMBER;
v_msg_error VARCHAR2(200);

BEGIN
    SELECT 
        e.nombre_edif,
        TO_CHAR(a.numrun_adm, '99G999G999') || '-' || a.dvrun_adm AS run_administrador,
        INITCAP(a.pnombre_adm || ' ' || a.snombre_adm || ' ' || a.appaterno_adm || ' ' || a.apmaterno_adm),
        TO_CHAR(rpgc.numrun_rpgc,'99G999G999') || '-' || rpgc.dvrun_rpgc AS run_responsable_pago_gc, 
        INITCAP(rpgc.pnombre_rpgc || ' ' || rpgc.snombre_rpgc || ' ' || rpgc.appaterno_rpgc || ' ' || rpgc.apmaterno_rpgc) AS nombre_responsable_pago_gc,
        gc.fecha_pago_gc
    INTO
        v_gcpc.nombre_edif,
        v_gcpc.run_administrador,
        v_gcpc.NOMBRE_ADMNISTRADOR,
        v_gcpc.run_responsable_pago_gc,
        v_gcpc.nombre_responsable_pago_gc,
        v_fecha_final_pago
    FROM edificio e
    INNER JOIN administrador a ON a.numrun_adm = e.numrun_adm
    INNER JOIN departamento d ON d.id_edif = e.id_edif
    INNER JOIN gasto_comun gc ON gc.nro_depto = d.nro_depto AND gc.id_edif = d.id_edif
    INNER JOIN responsable_pago_gasto_comun rpgc ON  rpgc.numrun_rpgc = gc.numrun_rpgc
    WHERE gc.id_edif = p_id_edif AND gc.nro_depto = p_nro_depto AND gc.anno_mes_pcgc = p_anno_mes_proceso; 
    
    --LOGICA INSERT EN TABLA gasto_comun_pago_cero y UPDATE EN TABLA gasto_comun SI TUVE 1 PAGO DURANTE LOS ULTIMOS 2 MESES
    IF p_numero_pagos = 1 THEN
            
        INSERT INTO gasto_comun_pago_cero VALUES(p_anno_mes_proceso,
                                                 p_id_edif,
                                                 v_gcpc.nombre_edif,
                                                 v_gcpc.run_administrador,
                                                 v_gcpc.NOMBRE_ADMNISTRADOR,
                                                 p_nro_depto,
                                                 v_gcpc.run_responsable_pago_gc,
                                                 v_gcpc.nombre_responsable_pago_gc,
                                                 p_valor_uf * 2,
                                                 p_observacion_1);
                                                 
        -- UPDATE QUE ACTUALIZA SOBRE LA TABLA gasto_comun LA MULTA CORRESPONDIENTE AL AÑO_MES DEL PROCESO                                         
        UPDATE gasto_comun 
        SET multa_gc = p_valor_uf * 2
        WHERE id_edif = p_id_edif AND nro_depto = p_nro_depto AND anno_mes_pcgc = p_anno_mes_proceso; 
        
        DBMS_OUTPUT.PUT_LINE('ID EDIFICIO: ' || p_id_edif);
        DBMS_OUTPUT.PUT_LINE('NOMBRE EDIFICIO: ' || v_gcpc.nombre_edif);
        DBMS_OUTPUT.PUT_LINE('NRO DEPTO: ' || p_id_edif || ' cuenta con 1 periodos de deuda');
        DBMS_OUTPUT.PUT_LINE('DEUDA ACUMULADA: ' || p_valor_uf * 2);
        DBMS_OUTPUT.PUT_LINE('OBSERVACION: ' || p_observacion_1);
        DBMS_OUTPUT.PUT_LINE('');
    
    --LOGICA INSERT EN TABLA gasto_comun_pago_cero y UPDATE EN TABLA gasto_comun SI TUVE 0 PAGO DURANTE LOS ULTIMOS 2 MESES
    ELSIF p_numero_pagos = 0 THEN
        INSERT INTO gasto_comun_pago_cero VALUES(p_anno_mes_proceso,
                                                 p_id_edif,
                                                 v_gcpc.nombre_edif,
                                                 v_gcpc.run_administrador,
                                                 v_gcpc.NOMBRE_ADMNISTRADOR,
                                                 p_nro_depto,
                                                 v_gcpc.run_responsable_pago_gc,
                                                 v_gcpc.nombre_responsable_pago_gc,
                                                 p_valor_uf * 4,
                                                 p_observacion_2 || v_fecha_final_pago);
        
        -- UPDATE QUE ACTUALIZA SOBRE LA TABLA gasto_comun LA MULTA CORRESPONDIENTE AL AÑO_MES DEL PROCESO
        UPDATE gasto_comun 
        SET multa_gc = p_valor_uf *4
        WHERE id_edif = p_id_edif AND nro_depto = p_nro_depto AND anno_mes_pcgc = p_anno_mes_proceso; 
        
        DBMS_OUTPUT.PUT_LINE('ID EDIFICIO: ' || p_id_edif);
        DBMS_OUTPUT.PUT_LINE('NOMBRE EDIFICIO: ' || v_gcpc.nombre_edif);
        DBMS_OUTPUT.PUT_LINE('NRO DEPTO: ' || p_id_edif || ' cuenta con 2 periodos de deuda');
        DBMS_OUTPUT.PUT_LINE('DEUDA ACUMULADA: ' || p_valor_uf * 4);
        DBMS_OUTPUT.PUT_LINE('OBSERVACION: ' || p_observacion_2 || v_fecha_final_pago);
        DBMS_OUTPUT.PUT_LINE('');
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('Se ha producido un error');
        
    END IF; 
    
    COMMIT;
    
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error);
            COMMIT;
        
        WHEN NO_DATA_FOUND THEN
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error); 
            COMMIT;
        
        WHEN OTHERS THEN    
            v_cod_error := SQLCODE;
            v_msg_error := SQLERRM;

            INSERT INTO error_log(fecha_log, cod_error, msg_error)
            VALUES (SYSDATE, v_cod_error, v_msg_error); 
            COMMIT;
END; 




