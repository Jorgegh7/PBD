SET SERVEROUTPUT ON;

-- VARIABLES BIND VALORES EXTERNOS MODIFICABLES
VAR b_valor_uf NUMBER; 
VAR b_anno_mes NUMBER; 
VAR b_observacion_1 VARCHAR2(200); 
VAR b_observacion_2 VARCHAR2(200); 

--INICIAMOS VASLORES VARIABLES BIND
EXEC :b_valor_uf := 29509; 
EXEC :b_anno_mes := 202605; 
EXEC :b_observacion_1 := 'Se realizará el corte de combustible y agua'; 
EXEC :b_observacion_2 := 'Se realizará el corte de combustible y agua a contar del '; 

DECLARE
v_cur_dep SYS_REFCURSOR; --DECLARACION CURSOR DINAMICO QUE RECIBIMOS COMO SALIDA DEL SP sp_dptos_nopago_2meses
v_anno_mes NUMBER := :b_anno_mes; 
v_anno_mes_p1 NUMBER := :b_anno_mes -2; 
v_anno_mes_p2 NUMBER := :b_anno_mes -1; 
v_observacion_1 VARCHAR2(200) := :b_observacion_1;
v_observacion_2 VARCHAR2(200) := :b_observacion_2;
v_nombre_edif VARCHAR2(30); 
v_nro_dpto NUMBER; 
v_id_edif NUMBER; 
v_nro_pagos NUMBER;
v_valor_uf NUMBER := :b_valor_uf; 

BEGIN
    --SP QUE ENTREGA LA LISTA DE DEPARTAMENTOS CON NO PAGO DURANTE LOS 2 MESES
    --NO HAY NECESIDAD DE HACER UN OPEN CURSOR
    sp_dptos_nopago_2meses(v_anno_mes_p1,v_anno_mes_p2, v_cur_dep); 
    
    --LOOP CON FETCH PARA TRABAJAR FILA POR FILA
    LOOP 
        FETCH v_cur_dep INTO v_nombre_edif, v_id_edif, v_nro_dpto, v_nro_pagos; 
        EXIT WHEN v_cur_dep%NOTFOUND; 
        
        --SP QUE HACER UN INSERT EN TABLA gasto_comun_pago_cero y UPDATE SOBRE gasto_comun RESPECTO A LA MULTA 
        sp_ins_dptos_nopago(v_anno_mes, v_id_edif, v_nro_dpto, v_valor_uf,v_observacion_1, v_observacion_2, v_nro_pagos); 
    END LOOP;  
    
    --CIERRE CURSOR
    CLOSE v_cur_dep;    
    
END; 
/

-- SELECT PARA COMPRABAR EL UPDATE DE LA PABLA GASTO COMUN
/*
SELECT 
    anno_mes_pcgc,
    id_edif,
    nro_depto,
    fecha_desde_gc,
    fecha_hasta_gc,
    multa_gc
FROM gasto_comun
WHERE anno_mes_pcgc = 202605 AND multa_gc > 0; 
*/