SET SERVEROUTPUT ON;

--PROCESOS:
-- ps_error_log : INSERTA EL LOG DE ERRORES EN LA TABLA errores_proceso
-- fn_descuento_3ra_edad  : CALCULA EL MULTIPLICADOR DESCUENTO 3RA EDAD
-- fn_nombre_especialidad : CALCULA EL NOMBRE DE LA ESPACIALIDAD DEL MEDICO
-- fn_edad_paciente : CALCULA LA EDAD DEL PACIENTE EN EL MOMENTO DE EJECUTARSE EL PROCESO
-- sp_pacientes_morosos : OBTIENE E INSERTA LOS VALORES REQUERIDOS EN LA TABLA pago_moroso

--SECUENCIA PARA SER UTILIZADA EN LA TABLA errores_proceso
CREATE SEQUENCE seq_errores_proceso
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

--==============================================================================
-- PACKAGE
--==============================================================================

--ESPECIFICACION PACKAGE pkg_pacientes_morosos
CREATE OR REPLACE PACKAGE pkg_pacientes_morosos IS
--VARIABLES ERROR
v_mesaje_error VARCHAR2(500); 
v_codigo_error NUMBER; 
v_subprograma VARCHAR2(30); 

--VARIABLES MULTA Y DESCUENTO
v_valor_multa NUMBER; 
v_valor_desc_mayores_70 NUMBER; 

-- PS QUE ALMACENA LOS ERRORES EN LA TABLA errores_proceso Y FN QUE RETORNA EL MULTIPLICADOR DE DESCUENTO 3RA EDAD 
PROCEDURE ps_error_log (p_subprograma VARCHAR2, p_mensaje_error VARCHAR2);
FUNCTION fn_descuento_3ra_edad (p_fecha_pago_paciente IN DATE, p_fecha_nacimiento IN DATE) RETURN NUMBER; 

-- CIERRE ESPECIFICACION PACKAGE
END pkg_pacientes_morosos; 

--BODY PACKAGE pkg_pacientes_morosos
CREATE OR REPLACE PACKAGE BODY pkg_pacientes_morosos IS
    PROCEDURE ps_error_log ( p_subprograma VARCHAR2, p_mensaje_error VARCHAR2)
    IS
    BEGIN
        INSERT INTO errores_proceso VALUES(seq_errores_proceso.NEXTVAL,
                                           p_subprograma,
                                           p_mensaje_error);

        COMMIT; 
    END ps_error_log;         
    
    FUNCTION fn_descuento_3ra_edad (p_fecha_pago_paciente IN DATE, p_fecha_nacimiento IN DATE) 
    RETURN NUMBER 
    IS
    v_error_edad_superior EXCEPTION; --EXCEPTION PARA EDADES > 100
    v_descuento_3ra_edad NUMBER;
    v_edad NUMBER; 
    
    BEGIN
        -- CALCULO DE LA EDAD
        v_edad := TRUNC(MONTHS_BETWEEN(p_fecha_pago_paciente, p_fecha_nacimiento)/12); 
        
        -- LOS VALORES SUPERIORES A 100 NO SE ENCUENTRAN SEGMENTADOS EN LA TABLA porc_descto_3ra_edad
        IF v_edad > 100 THEN
            RAISE v_error_edad_superior; 
        END IF; 
        
        SELECT porcentaje_descto
        INTO v_descuento_3ra_edad
        FROM porc_descto_3ra_edad
        WHERE v_edad BETWEEN anno_ini AND anno_ter; 
        
        -- CALCULO DESCUENTO EJ: 0.9 -> 10% DESCUENTO
        v_descuento_3ra_edad := (100 - v_descuento_3ra_edad)/100; 
        
        RETURN v_descuento_3ra_edad;
        
        EXCEPTION
            -- SE RETORNA EL ULTIMO VALOR DE LA TABLA porc_descto_moroso 18% DCTO PARA EDADES > 100
            WHEN v_error_edad_superior THEN
            v_descuento_3ra_edad := 0.82;
            RETURN v_descuento_3ra_edad;
            
            WHEN OTHERS THEN
            v_mesaje_error := SQLERRM; 
            ps_error_log('fn_descuento_3ra_edad', v_mesaje_error);
            RETURN NULL;
    
    END fn_descuento_3ra_edad;   
    
-- CIERRE BODY PACKAGE
END pkg_pacientes_morosos;

--==============================================================================
-- FUNCIONES Y PROCESO ALMACENADO
--==============================================================================

--FUNCION QUE RETORNA EL NOMBRE ESPECIALIDAD ATENCION
CREATE OR REPLACE FUNCTION fn_nombre_especialidad(p_ate_id NUMBER)
RETURN VARCHAR2
IS
v_nombre_especialidad VARCHAR2(30);
BEGIN
    SELECT e.nombre
    INTO v_nombre_especialidad
    FROM especialidad e
    RIGHT JOIN medico m ON m.esp_id = e.esp_id
    INNER JOIN atencion a ON a.med_run = m.med_run
    WHERE a.ate_id = p_ate_id; 
    
    RETURN v_nombre_especialidad;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        pkg_pacientes_morosos.v_mesaje_error := SQLERRM; 
        pkg_pacientes_morosos.v_codigo_error := SQLCODE;
        pkg_pacientes_morosos.v_subprograma := 'fn_nombre_especialidad';
            
        pkg_pacientes_morosos.ps_error_log (pkg_pacientes_morosos.v_subprograma, pkg_pacientes_morosos.v_mesaje_error);
        RETURN NULL;
        
     WHEN OTHERS THEN
        pkg_pacientes_morosos.v_mesaje_error := SQLERRM; 
        pkg_pacientes_morosos.v_codigo_error := SQLCODE;
        pkg_pacientes_morosos.v_subprograma := 'fn_nombre_especialidad';
            
        pkg_pacientes_morosos.ps_error_log (pkg_pacientes_morosos.v_subprograma, pkg_pacientes_morosos.v_mesaje_error);
        RETURN NULL;      
END; 

-- FUNCION EDAD PACIENTE PROCESO
CREATE OR REPLACE FUNCTION fn_edad_paciente(p_fecha_pago_paciente IN DATE, p_fecha_nacimiento IN DATE)
RETURN NUMBER
IS
v_edad NUMBER; 

BEGIN
    v_edad := TRUNC(MONTHS_BETWEEN(p_fecha_pago_paciente, p_fecha_nacimiento)/12);
    RETURN v_edad;
    
    EXCEPTION
        WHEN OTHERS THEN
            pkg_pacientes_morosos.v_mesaje_error := SQLERRM; 
            pkg_pacientes_morosos.v_codigo_error := SQLCODE;
            pkg_pacientes_morosos.v_subprograma := 'fn_edad_paciente';
                
            pkg_pacientes_morosos.ps_error_log (pkg_pacientes_morosos.v_subprograma, pkg_pacientes_morosos.v_mesaje_error);
            RETURN NULL;        
END; 


-- PROCESO ALMACENADO sp_pacientes_morosos
CREATE OR REPLACE PROCEDURE sp_pacientes_morosos(p_annio_proceso IN NUMBER)
IS
v_annio_proceso NUMBER := p_annio_proceso;
v_observacion VARCHAR2(200); 
v_nombre_paciente VARCHAR2(50);
v_edad_paciente NUMBER; 
v_dias_morosidad NUMBER; 
v_especialidad VARCHAR2(25);
v_valor_dia_multa NUMBER;  

-- VARRAY QUE ALMACENA LOS VALORES DIAS SEGUN ESPECIALIDAD
TYPE t_multa_dia_esp IS VARRAY(7) OF NUMBER;
va_multa_dia_esp t_multa_dia_esp := t_multa_dia_esp(1200,1300,1700, 1900, 1100, 2000, 2300);  

CURSOR c_pago_moroso(p_annio_proceso NUMBER) IS
        SELECT
            p.pac_run,
            p.dv_run,
            p.pnombre,
            p.snombre,
            p.apaterno,
            p.amaterno,
            p.fecha_nacimiento,
            pa.ate_id,
            pa.fecha_venc_pago,
            pa.fecha_pago,
            a.costo
        FROM pago_atencion pa
        INNER JOIN atencion a ON a.ate_id = pa.ate_id
        INNER JOIN paciente p ON p.pac_run = a.pac_run
        WHERE fecha_pago > fecha_venc_pago AND EXTRACT(YEAR FROM fecha_pago) = p_annio_proceso
        ORDER BY pa.fecha_venc_pago, p.apaterno; 

-- VARIABLE ESPEJO DE CURSOR        
v_reg_moroso c_pago_moroso%ROWTYPE;

BEGIN
    -- TRUNCADO TABLA pago_moroso
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pago_moroso';
    
    -- COMPROBAR SI EL CURSOR NO ESTA ABIERTO
    IF NOT c_pago_moroso%ISOPEN THEN
        -- ABRE CURSOR CON PARAMETRO AÑO DE PROCESO
        OPEN c_pago_moroso(v_annio_proceso); 
    END IF;
    
    LOOP
        FETCH c_pago_moroso INTO v_reg_moroso; 
        EXIT WHEN c_pago_moroso%NOTFOUND; 
        
        v_nombre_paciente := v_reg_moroso.pnombre || ' ' || v_reg_moroso.snombre || ' ' || v_reg_moroso.apaterno || ' ' || v_reg_moroso.amaterno;
        v_dias_morosidad := v_reg_moroso.fecha_pago - v_reg_moroso.fecha_venc_pago; 
        v_especialidad := fn_nombre_especialidad(v_reg_moroso.ate_id); 
        
        -- CASE QUE SEGMENTA EL VALOR MULTA DIA SEGUN ESPECIALIDAD, VALORES ALMACENADOS EN VARRAY 
        v_valor_dia_multa := 
            CASE 
                WHEN v_especialidad = 'Medicina General' THEN  va_multa_dia_esp(1)
                WHEN v_especialidad = 'Traumatologia' THEN  va_multa_dia_esp(2)
                WHEN v_especialidad = 'Neurologia' OR v_especialidad = 'Pediatria' THEN  va_multa_dia_esp(3)
                WHEN v_especialidad = 'Oftalmologia' THEN  va_multa_dia_esp(4)
                WHEN v_especialidad = 'Geriatria' THEN  va_multa_dia_esp(5)
                WHEN v_especialidad = 'Ginecologia' OR v_especialidad = 'Gastroenterologia' THEN  va_multa_dia_esp(6)
                WHEN v_especialidad = 'Dermatologia' THEN  va_multa_dia_esp(7)
            END; 
        
        -- ALMACENA EL VALOR MULTA PARA TODOS          
        pkg_pacientes_morosos.v_valor_multa := v_valor_dia_multa * v_dias_morosidad;          
        
        -- LLAMADO A fn_edad_paciente PARA OBTENER LA EDAD DEL PACIENTE 
        v_edad_paciente := fn_edad_paciente(v_reg_moroso.fecha_pago, v_reg_moroso.fecha_nacimiento); 
        
        -- SI EL PACIENTE TIENE > 70 SE MODIFICA EL VALOR MULTA Y SE GENERA UNA OBSERVACION
        -- SE LLAMA A fn_descuento_3ra_edad PARA OBTENER EL % DCTO SEGUN LA EDAD
        IF v_edad_paciente >= 70 THEN 
            pkg_pacientes_morosos.v_valor_multa := (v_valor_dia_multa * pkg_pacientes_morosos.fn_descuento_3ra_edad(v_reg_moroso.fecha_pago, v_reg_moroso.fecha_nacimiento)) * v_dias_morosidad; 
            v_observacion := 'Paciente tenía ' || v_edad_paciente || ' a la fecha de atencíon. Se aplicó descuento paciente mayor de 70 años.'; 
        ELSE 
            v_observacion := NULL;     
        END IF; 
        
        DBMS_OUTPUT.PUT_LINE('RUT:' || v_reg_moroso.pac_run);
        DBMS_OUTPUT.PUT_LINE('DV: ' || v_reg_moroso.dv_run);
        DBMS_OUTPUT.PUT_LINE('NOMBRE: ' || v_nombre_paciente);
        DBMS_OUTPUT.PUT_LINE('ATENCION ID: ' || v_reg_moroso.ate_id);
        DBMS_OUTPUT.PUT_LINE('FECHA VENCIMIENTO PAGO: ' || v_reg_moroso.fecha_venc_pago);
        DBMS_OUTPUT.PUT_LINE('DIAS MOROSIDAD: ' || v_dias_morosidad);
        DBMS_OUTPUT.PUT_LINE('ESPECIALIDAD: ' || v_especialidad);
        DBMS_OUTPUT.PUT_LINE('COSTO ATENCION: ' ||  v_reg_moroso.costo);
        DBMS_OUTPUT.PUT_LINE('MONTO MULTA: ' ||  pkg_pacientes_morosos.v_valor_multa);
        DBMS_OUTPUT.PUT_LINE('OBSERVACION: ' ||  v_observacion);
        
        DBMS_OUTPUT.PUT_LINE('FECHA NACIMIENTO: ' || v_reg_moroso.fecha_nacimiento);
        DBMS_OUTPUT.PUT_LINE('EDAD PACIENTE: ' || v_edad_paciente);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- INSERTAN LOS VALORES EN pago_moroso
        INSERT INTO pago_moroso VALUES(v_reg_moroso.pac_run,
                                       v_reg_moroso.dv_run,
                                       v_nombre_paciente,
                                       v_reg_moroso.ate_id,
                                       v_reg_moroso.fecha_venc_pago,
                                       v_reg_moroso.fecha_pago,
                                       v_dias_morosidad,
                                       v_especialidad,
                                       v_reg_moroso.costo,
                                       pkg_pacientes_morosos.v_valor_multa,
                                       v_observacion);  
    
    -- CIERRE LOOP CURSOR c_pago_moroso  
    END LOOP;
    
    -- CIERRE CURSOR c_pago_moroso
    CLOSE c_pago_moroso; 
    
    COMMIT; 
    
    EXCEPTION
        WHEN OTHERS THEN 
            pkg_pacientes_morosos.v_mesaje_error := SQLERRM; 
            pkg_pacientes_morosos.v_codigo_error := SQLCODE;
            pkg_pacientes_morosos.v_subprograma := 'sp_pacientes_morosos';
            
            pkg_pacientes_morosos.ps_error_log (pkg_pacientes_morosos.v_subprograma, pkg_pacientes_morosos.v_mesaje_error);

END; 

--==============================================================================
-- TRIGGER
--==============================================================================
-- TRIGGER QUE ENTREA UN MENSAJE LUEGO DE INSERTAR 1 FILA EN TABLA trg_aud_ins_pago_moroso
CREATE OR REPLACE TRIGGER trg_aud_ins_pago_moroso
AFTER INSERT ON pago_moroso
FOR EACH ROW
BEGIN 
    DBMS_OUTPUT.PUT_LINE('SE HA INSERTADO 1 VALOR EN LA TABLA pago_moroso');
    DBMS_OUTPUT.PUT_LINE('');
END; 

--==============================================================================
-- PRUEBAS FUNCIONES
--==============================================================================

--EJECUCION FUNCION fn_nombre_especialidad
VAR b_ate_id NUMBER; 
EXEC :b_ate_id := 100; 

DECLARE
v_ate_id NUMBER := :b_ate_id; 
v_nombre_especialidad VARCHAR2(30); 
BEGIN
    v_nombre_especialidad := fn_nombre_especialidad(v_ate_id); 
    DBMS_OUTPUT.PUT_LINE('ID ATENCION: ' || v_ate_id);
    DBMS_OUTPUT.PUT_LINE('NOMBRE ESPECIALIDAD: ' || v_nombre_especialidad);
END; 

-- ============================================================================
-- EJECUCION SP PRINCIPAL 
-- ============================================================================

--EJECUCION SP sp_pacientes_morosos
VAR b_annio_proceso NUMBER; 
EXEC :b_annio_proceso := EXTRACT(YEAR FROM SYSDATE) -1; 

EXEC sp_pacientes_morosos(:b_annio_proceso); 

