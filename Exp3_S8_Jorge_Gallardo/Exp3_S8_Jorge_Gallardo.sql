SET SERVEROUTPUT ON;

--==============================================================================
-- TRIGGER
--==============================================================================

CREATE OR REPLACE TRIGGER trg_consumos_huesped
AFTER INSERT OR UPDATE OR DELETE ON consumo
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        UPDATE total_consumos
        SET monto_consumos = monto_consumos + :NEW.monto
        WHERE id_huesped = :NEW.id_huesped;
    ELSIF UPDATING THEN
        UPDATE total_consumos
        SET monto_consumos = (monto_consumos - :OLD.monto) + :NEW.monto
        WHERE id_huesped = :NEW.id_huesped; 
    ELSIF DELETING THEN    
        UPDATE total_consumos
        SET monto_consumos = monto_consumos - :OLD.monto
        WHERE id_huesped = :OLD.id_huesped;        
    END IF;
END
; 
/
-- PRUEBA TRIGGER INSERT 
INSERT INTO consumo
VALUES(11530,1587,340006,150); 

-- PRUEBA TRIGGER DELETE 
DELETE FROM consumo WHERE id_consumo = 11473; 

-- PRUEBA TRIGGER UPDATE 
UPDATE consumo
SET monto = 95
WHERE id_consumo = 10688; 

--==============================================================================
-- FUNCIONES ALMACENADAS
--==============================================================================

-- FUNCION CONSUMO HUESPED RETORNA EL TOTAL DEL CONSUMO EN DOLARES
CREATE OR REPLACE FUNCTION fn_consumo_huesped(p_id_huesped IN NUMBER, p_descuento_consumo OUT NUMBER)
RETURN NUMBER
IS
v_consumo NUMBER :=0; 
v_descuento NUMBER := 0;
v_monto_maximo NUMBER := 0;         --ALMACENA EL VALOR MAXIMO DE LA TABLA tamos_consumos
v_maximo_descuento NUMBER := 0;      --ALMACENA EL DESCUENTO MAXIMO DE LA TABLA tamos_consumos
v_consumo_fuera_rango EXCEPTION; 
 
BEGIN
    --OBTENER EL VALOR VALOR MAXIMO DEL RANGO Y EL MAXIMO DESCUENTO
    SELECT vmax_tramo, pct
    INTO v_monto_maximo, v_maximo_descuento
    FROM tramos_consumos
    WHERE vmax_tramo = (SELECT MAX(vmax_tramo) FROM tramos_consumos);
    
    --OBTENER EL CONSUMO POR HUESPED
    SELECT monto_consumos
    INTO v_consumo
    FROM total_consumos 
    WHERE id_huesped = p_id_huesped; 
    
    --SI EL CONSUMO EXCEDE EL MAXIMO SE LEVANTA LA EXCEPTION
    IF v_consumo > v_monto_maximo THEN
        RAISE v_consumo_fuera_rango; 
    END IF;     
    
    --OBTENEMOS EL % DESCUENTO SEGUN EL TRAMO
    SELECT pct
    INTO v_descuento
    FROM tramos_consumos
    WHERE v_consumo BETWEEN vmin_tramo AND vmax_tramo;
    
    --OUT DESCUENTO CONSUMO EN DOLARES
    p_descuento_consumo := v_consumo * v_descuento; 
    
    --RETORNA EL TOTAL CONSUMIDO
    RETURN v_consumo;
    
EXCEPTION
    WHEN v_consumo_fuera_rango THEN
        pkg_utilidades_hotel.v_codigo_error := -3001; 
        pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || 'Fuera del rango maximo tabla tramos_consumos';
        pkg_utilidades_hotel.v_subprograma := 'fn_consumo_huesped_tramos_consumos'; 
        pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar los consumos del cliente con ID ' || p_id_huesped;
           
        pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error);
        
        --PARA QUIENES ESTAN POR SOBRE EL RANGO SUPERIOR EL % DESCUENTO ES EL VALOR MAXIMO DESCUENTO DE LA TABLA tramos_consumos
        p_descuento_consumo := v_consumo * v_maximo_descuento; 
        RETURN v_consumo;
        
    WHEN NO_DATA_FOUND THEN
        pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
        pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
        pkg_utilidades_hotel.v_subprograma := 'fn_consumo_huesped'; 
        pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar los consumos del cliente con ID ' || p_id_huesped;
           
        pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error);
        p_descuento_consumo := 0; 
        RETURN v_consumo;
        
    WHEN OTHERS THEN
        pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
        pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
        pkg_utilidades_hotel.v_subprograma := 'fn_consumo_huesped'; 
        pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar los consumos del cliente con ID ' || p_id_huesped;
           
        pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error);
        p_descuento_consumo := 0; 
        RETURN v_consumo;       
END; 
/

-- PRUEBA fn_consumo_huesped
VAR b_cliente NUMBER; 
EXEC :b_cliente := 340001; 

DECLARE
v_cliente NUMBER := :b_cliente; 
v_monto NUMBER;
v_descuento NUMBER; 
BEGIN
    v_monto := fn_consumo_huesped(v_cliente, v_descuento); 
    DBMS_OUTPUT.PUT_LINE('El consumo del cliente: ' || v_cliente || ' es: ' || v_monto);
    DBMS_OUTPUT.PUT_LINE('DESCUENTO: ' || v_descuento);
END; 
/

-- FUNCION fn_nom_desc_agencia RETORNA EL NOMBRE Y EL DESCUENTO DE LA AGENCIA 
CREATE OR REPLACE FUNCTION fn_nom_desc_agencia(p_id_huesped IN NUMBER, p_descuento OUT NUMBER)
RETURN VARCHAR2
IS
v_nombre_agencia VARCHAR2(35);
BEGIN
    --OBTIENE EL NOMBRE DE LA AGENCIA
    SELECT a.nom_agencia
    INTO v_nombre_agencia
    FROM agencia a
    LEFT JOIN huesped h ON h.id_agencia = a.id_agencia
    WHERE h.id_huesped = p_id_huesped;
    
    --COMPRUEBA SI EL NONBRE DE LA AGENCIA ES 'VIAJES ALBERTI' PARA APLICAR DESCUENTO
    --OUT p_descuento con el valor de descuento
    IF v_nombre_agencia = 'VIAJES ALBERTI' THEN
        p_descuento := 0.12;
    ELSE
        p_descuento := 0;
    END IF;     
    
    RETURN v_nombre_agencia; 
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
        pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
        pkg_utilidades_hotel.v_subprograma := 'fn_nom_desc_agencia'; 
        pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar la agencia del cliente con ID ' || p_id_huesped;
           
        pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error);
        p_descuento := 0;
        v_nombre_agencia := 'SIN AGENCIA'; 
        RETURN v_nombre_agencia;
        
    WHEN OTHERS THEN
        pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
        pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
        pkg_utilidades_hotel.v_subprograma := 'fn_nom_desc_agencia'; 
        pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar la agencia del cliente con ID ' || p_id_huesped;
           
        pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error); 
        p_descuento := 0;
        v_nombre_agencia := 'SIN AGENCIA'; 
        RETURN v_nombre_agencia;      
END; 
/

-- PRUEBA fn_nom_desc_agencia
VAR b_cliente NUMBER; 
EXEC :b_cliente := 340049; 

DECLARE
v_cliente NUMBER := :b_cliente; 
v_nombre_agencia VARCHAR2(35);
v_descuento NUMBER; 
BEGIN
    v_nombre_agencia := fn_nom_desc_agencia(v_cliente, v_descuento); 
    DBMS_OUTPUT.PUT_LINE('CLIENTE ID: ' || v_cliente);
    DBMS_OUTPUT.PUT_LINE('NOMBRE AGENCIA: ' || v_nombre_agencia);
    DBMS_OUTPUT.PUT_LINE('DESCUENTO: ' || v_descuento);    
END; 
/

--FUNCION fn_calculo_alojamiento QUE CALCULA EL TOTAL DEL VALOR ALOJAMIENTO
CREATE OR REPLACE FUNCTION fn_calculo_alojamiento(p_id_reserva IN NUMBER, p_estadia IN NUMBER, p_valor_dolar IN NUMBER, p_valor_dia_huesped IN NUMBER)
RETURN NUMBER
IS
v_total_aloj_dolar NUMBER := 0; 
v_cant_huespedes NUMBER := 0; 
v_total_aloj_pesos NUMBER := 0;
v_total_personas NUMBER; 
v_subtotal_pesos NUMBER;  

CURSOR cur_aloj IS
    SELECT
        dr.id_habitacion,
        h.valor_habitacion,
        h.valor_minibar,
        h.tipo_habitacion
    FROM detalle_reserva dr
    INNER JOIN habitacion h ON h.id_habitacion = dr.id_habitacion
    WHERE dr.id_reserva = p_id_reserva; 
BEGIN
    FOR reg_cur IN cur_aloj
    
    --LOOP QUE SUMA TODAS LAS HABITACIONES QUE POSEE UNA RESERVA
    LOOP
        --CALCULA EL TOTAL ALOJAMIENTO EN DOLARES CONSIDERANDO EL VALOR HABITACION Y EL MINIBAR 
        -- AMBOS VALORES SON DE COBRO DIARIO POR LO QUE ES NECESARIO CONOCER LA ESTADIA DE LOS HUESPEDES
        v_total_aloj_dolar := (reg_cur.valor_habitacion + reg_cur.valor_minibar) * p_estadia;
        
        /*
        DETALLE EN LA LOGICA:
        No se especifica si el valor del cobro por persona es diario o si es un cobro único.
        
        A cada huésped se le cobrarán $35mil pesos por la cantidad de personas que se 
        hospedará.  
        El pago por concepto de estadía o alojamiento debe considerar el valor de la habitación 
        más el valor del minibar. Ambos valores son diarios. 
        
        Respecto a esta diferencia en el detalle decidí que de sea cobro unico.
        En un futuro se puede implementar a un cobro diario multiplicando 
        v_mult_valor_persona * p_estadia
        */
        
        --CALCULA EL TOTAL POR NUMERO DE PERSONAS
        --ESTE VALOR SE ENCUENTRA EN PESOS EN EL CASO ACTUAL Y SE ENTREGA COMO PARAMETRO
        v_cant_huespedes := 
            CASE
                WHEN reg_cur.tipo_habitacion = 'S' THEN p_valor_dia_huesped
                WHEN reg_cur.tipo_habitacion = 'D' THEN p_valor_dia_huesped * 2
                WHEN reg_cur.tipo_habitacion = 'T' THEN p_valor_dia_huesped * 3
                WHEN reg_cur.tipo_habitacion = 'C' THEN p_valor_dia_huesped * 4
            END;     
            
        v_subtotal_pesos := (v_total_aloj_dolar * p_valor_dolar) +  v_cant_huespedes;
        v_total_aloj_pesos := v_total_aloj_pesos + v_subtotal_pesos; 
        
    END LOOP; 
    
    RETURN v_total_aloj_pesos; 
    
    EXCEPTION
        WHEN OTHERS THEN
            pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
            pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
            pkg_utilidades_hotel.v_subprograma := 'fn_calculo_alojamiento'; 
            pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar los valores de alojamiento con reserva ID ' || p_id_reserva;
               
            pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error); 
            RETURN v_total_aloj_pesos;
    
END; 
/

--PRUEBA FUNCION fn_calculo_alojamiento 
VAR b_id_reserva NUMBER; 
VAR b_estadia NUMBER;
VAR b_valor_dolar NUMBER;
VAR b_valor_dia_huesped NUMBER; 
    
EXEC :b_id_reserva := 862; 
EXEC :b_estadia := 9;
EXEC :b_valor_dolar := 915;
EXEC :b_valor_dia_huesped := 35000;    

DECLARE
v_id_reserva NUMBER := :b_id_reserva; 
v_estadia NUMBER := :b_estadia; 
v_dolar NUMBER := :b_valor_dolar; 
v_total_alojamiento NUMBER; 
v_valor_dia_huesped NUMBER := :b_valor_dia_huesped; 
    
BEGIN 
    v_total_alojamiento := fn_calculo_alojamiento(v_id_reserva, v_estadia, v_dolar, v_valor_dia_huesped);
    DBMS_OUTPUT.PUT_LINE('ID RESERVA: ' || v_id_reserva);
    DBMS_OUTPUT.PUT_LINE('TOTAL ALOJAMIENTO: ' || v_total_alojamiento);
END;   
/

--==============================================================================
-- PACKAGE
--==============================================================================

--ESPECIFICACION PACKAGE pkg_utilidades_hotel
CREATE OR REPLACE PACKAGE pkg_utilidades_hotel IS

--VARIABLES ERROR
v_mensaje_error VARCHAR2(300); 
v_codigo_error NUMBER; 
v_subprograma VARCHAR2(30);
v_descripcion_error VARCHAR2(500);

v_monto_tours NUMBER; 

PROCEDURE sp_error_log (p_subprograma VARCHAR2, p_mensaje_error VARCHAR2);
FUNCTION fn_tours_huesped(p_id_huesped IN NUMBER) RETURN NUMBER; 

END pkg_utilidades_hotel; 
/

--BODY PACKAGE pkg_utilidades_hotel
CREATE OR REPLACE PACKAGE BODY pkg_utilidades_hotel IS

    --PROCEDIMIENTO QUE ALMACENA LOS ERRORES 
    PROCEDURE sp_error_log ( p_subprograma VARCHAR2, p_mensaje_error VARCHAR2)
    IS
    BEGIN
        INSERT INTO reg_errores VALUES(sq_error.NEXTVAL,
                                       p_subprograma,
                                       p_mensaje_error);

        COMMIT; 
    END sp_error_log;
    
    --FUNCION QUE RETORNA EL MONTO TOTAL DE TOURS SEGUN HUESPED
    FUNCTION fn_tours_huesped(p_id_huesped IN NUMBER)
    RETURN NUMBER
    IS
    v_monto_total NUMBER := 0; 
    
    CURSOR cur_tours_huesped IS
        SELECT ht.num_personas, t.valor_tour
        FROM huesped_tour ht
        JOIN tour t ON ht.id_tour = t.id_tour
        WHERE ht.id_huesped = p_id_huesped;
    
    BEGIN
        FOR reg_tours IN cur_tours_huesped 
        LOOP
            v_monto_total := v_monto_total + (reg_tours.valor_tour * reg_tours.num_personas);
        END LOOP;
    
    RETURN v_monto_total;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_codigo_error := SQLCODE; 
            v_mensaje_error := v_codigo_error || ': ' || SQLERRM;
            v_subprograma := 'fn_tours_huesped'; 
            v_descripcion_error := 'ERROR EN LA FUNCION ' || v_subprograma || ' al recuperar los Tours del cliente con ID ' || p_id_huesped;
           
            sp_error_log(v_descripcion_error, v_mensaje_error); 
            RETURN v_monto_total;
           
        WHEN OTHERS THEN
            v_codigo_error := SQLCODE; 
            v_mensaje_error := v_codigo_error || ': ' || SQLERRM;
            v_subprograma := 'fn_tours_huesped'; 
            v_descripcion_error := 'ERROR EN LA FUNCION ' || v_subprograma || ' al recuperar los Tours del cliente con ID ' || p_id_huesped;
           
            sp_error_log(v_descripcion_error, v_mensaje_error);
            RETURN v_monto_total;
           
    END fn_tours_huesped; 
    
END pkg_utilidades_hotel;
/

-- PRUEBA TOUR HUESPED
VAR b_cliente NUMBER; 
EXEC :b_cliente := 340019; 

DECLARE
v_cliente NUMBER := :b_cliente; 
v_monto_tours NUMBER; 
BEGIN
    v_monto_tours := pkg_utilidades_hotel.fn_tours_huesped(v_cliente); 
    DBMS_OUTPUT.PUT_LINE('CLIENTE ID: ' || v_cliente);
    DBMS_OUTPUT.PUT_LINE('MONTO TOURS: ' || v_monto_tours);
END; 
/
--==============================================================================
-- PROCEDIMIENTO ALMACENADO PRINCIPAL
--==============================================================================

CREATE OR REPLACE PROCEDURE sp_cal_huesped_salida(p_valor_dolar IN NUMBER, p_dia_proceso IN DATE, p_valor_dia_huesped IN NUMBER)
IS
v_total_alojamiento NUMBER; 
v_nombre_huesped VARCHAR2(60); 
v_nombre_agencia VARCHAR2(40);
v_descuento_agencia NUMBER; 
v_prc_desc_agencia NUMBER := 0; 
v_consumo NUMBER := 0; 
v_prc_desc_consumo NUMBER := 0; 
v_descuento_consumo NUMBER := 0; 
v_valor_tours NUMBER := 0; 
v_subtotal NUMBER := 0; 
v_total NUMBER; 

CURSOR cur_salida_huespedes(p_dia_proceso DATE) IS
    SELECT 
    h.id_huesped,
    h.nom_huesped,
    h.appat_huesped,
    h.apmat_huesped,
    r.id_reserva,
    r.estadia   
FROM huesped h
INNER JOIN reserva r ON r.id_huesped = h.id_huesped
WHERE r.ingreso = p_dia_proceso - r.estadia; 

reg_salida cur_salida_huespedes%ROWTYPE; 

BEGIN
    --TRUNCATE DE TABLAS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE reg_errores'; 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_diario_huespedes';
    
    --ABRIR CURSOR
    OPEN cur_salida_huespedes(p_dia_proceso);
    
    --LOOP CURSOR
    LOOP
        FETCH cur_salida_huespedes INTO reg_salida;
        EXIT WHEN cur_salida_huespedes%NOTFOUND; 
        
        --BLOQUE ANONIMO INTERNO LOOP
        BEGIN
            --NOMBRE HUESPED
            v_nombre_huesped := INITCAP(reg_salida.nom_huesped || ' ' || reg_salida.appat_huesped || ' ' || reg_salida.apmat_huesped);
           
            --NOMBRE AGENCIA
            v_nombre_agencia := fn_nom_desc_agencia(reg_salida.id_huesped, v_prc_desc_agencia); 
            
            -- fn_calculo_alojamiento RETORNA EL TOTAL DE ALOJAMIENTO INCLUIDO VALOR HABITACION + MINIBAR
            -- Y EL VALOR POR PERSONA SEGUN LA EL TIPO DE HABITACION
            v_total_alojamiento := fn_calculo_alojamiento(reg_salida.id_reserva, reg_salida.estadia, p_valor_dolar, p_valor_dia_huesped);
            
            --TOTAL CONSUMO
            v_consumo := fn_consumo_huesped(reg_salida.id_huesped, v_prc_desc_consumo) * p_valor_dolar;
            
            --TOURS
            v_valor_tours := pkg_utilidades_hotel.fn_tours_huesped(reg_salida.id_huesped) * p_valor_dolar; 
            
            -- EL SUBTOTAL INCLYUYE TOTAL ALOJAMIENTO + CONSUMO
            v_subtotal := v_total_alojamiento + v_consumo; 
            
            --DESCUENTO CONSUMO
            v_descuento_consumo := ROUND(v_prc_desc_consumo * p_valor_dolar);
            
            --DESCUENTO AGENCIA
            v_descuento_agencia := ROUND(v_total_alojamiento * v_prc_desc_agencia); 
            
            --TOTAL INCULUYE EL SUBTOTAL MENOS LOS DESCUENTOS
            v_total := v_subtotal - v_descuento_consumo - v_descuento_agencia; 
            
            --INSERT EN TABLA detalle_diario_huespedes
            INSERT INTO detalle_diario_huespedes VALUES(reg_salida.id_huesped,
                                                        v_nombre_huesped,
                                                        v_nombre_agencia,
                                                        v_total_alojamiento,
                                                        v_consumo,
                                                        v_valor_tours,
                                                        v_subtotal,
                                                        v_descuento_consumo,
                                                        v_descuento_agencia,
                                                        v_total); 
                                                            
            DBMS_OUTPUT.PUT_LINE('ID: ' || reg_salida.id_huesped);
            DBMS_OUTPUT.PUT_LINE('HUESPED: ' || v_nombre_huesped);
            DBMS_OUTPUT.PUT_LINE('AGENCIA: ' || v_nombre_agencia);
            DBMS_OUTPUT.PUT_LINE('ALOJAMIENTO: ' || v_total_alojamiento);
            DBMS_OUTPUT.PUT_LINE('CONSUMOS: ' || v_consumo);
            DBMS_OUTPUT.PUT_LINE('SUBTOTAL: ' || v_subtotal);
            DBMS_OUTPUT.PUT_LINE('DESCUENTO CONSUMO: ' || v_descuento_consumo);
            DBMS_OUTPUT.PUT_LINE('DESCUENTO AGENCIA: ' || v_descuento_agencia);
            DBMS_OUTPUT.PUT_LINE('TOTAL: ' || v_total);
            DBMS_OUTPUT.PUT_LINE('');
            
            --BLOQUE EXCEPTION INTERNO LOOP
            EXCEPTION
                WHEN OTHERS THEN
                pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
                pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
                pkg_utilidades_hotel.v_subprograma := 'sp_cal_huesped_salida_loop'; 
                pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar datos del huesped ID ' || reg_salida.id_huesped;
                   
                pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error); 
        
        --CIERRE BLOQUE ANONIMO LOOP     
        END;
    END LOOP; 
    
    --CIERRE CURSOR
    CLOSE cur_salida_huespedes; 
    
    COMMIT; 
    
    --BLOQUE EXCEPTION PRINCIPAL
    EXCEPTION
        WHEN OTHERS THEN
            pkg_utilidades_hotel.v_codigo_error := SQLCODE; 
            pkg_utilidades_hotel.v_mensaje_error := pkg_utilidades_hotel.v_codigo_error || ': ' || SQLERRM;
            pkg_utilidades_hotel.v_subprograma := 'sp_cal_huesped_salida'; 
            pkg_utilidades_hotel.v_descripcion_error := 'ERROR EN LA FUNCION ' || pkg_utilidades_hotel.v_subprograma || ' al recuperar los datos de calculo de los huespedes.';
               
            pkg_utilidades_hotel.sp_error_log(pkg_utilidades_hotel.v_descripcion_error, pkg_utilidades_hotel.v_mensaje_error); 
END;   
/

--CALCULO PROCEDIMIENTO PRINCIPAL sp_cal_huesped_salida 
VAR b_valor_dolar NUMBER;
VAR b_valor_dia_huesped NUMBER;
VAR b_fecha_proceso VARCHAR2; 

EXEC :b_valor_dolar := 915;
EXEC :b_valor_dia_huesped := 35000;  
EXEC :b_fecha_proceso := '18/08/2021'

DECLARE
v_fecha_proceso DATE:= TO_DATE(:b_fecha_proceso);   
v_dolar NUMBER := :b_valor_dolar; 
v_valor_dia_huesped NUMBER := :b_valor_dia_huesped; 
    
BEGIN 
    sp_cal_huesped_salida(v_dolar, v_fecha_proceso, v_valor_dia_huesped);
END;     
/


