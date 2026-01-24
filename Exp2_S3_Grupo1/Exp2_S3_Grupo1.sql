SET serveroutput on;

--======================================
-- EXP 2 SEMANA 3 : CASO 1
--======================================

SAVEPOINT sp_pago_moroso; 

VAR b_fecha_proceso DATE;
EXEC :b_fecha_proceso := SYSDATE;  

DECLARE

    --DECLARACIÓN DE CURSOS EXPLICITO
    CURSOR cur_multa IS
        SELECT 
            p.pac_run,
            p.dv_run, 
            p.pnombre,
            p.snombre,
            p.apaterno,
            p.amaterno,
            p.fecha_nacimiento,
            a.ate_id,
            pa.fecha_venc_pago,
            pa.fecha_pago, 
            e.nombre,
            e.esp_id         
        FROM paciente p 
        INNER JOIN atencion a ON a.pac_run = p.pac_run
        INNER JOIN pago_atencion pa ON pa.ate_id = a.ate_id
        INNER JOIN especialidad e ON e.esp_id = a.esp_id
        WHERE pa.fecha_pago > pa.fecha_venc_pago 
            AND EXTRACT(YEAR FROM pa.fecha_pago) = EXTRACT(YEAR FROM :b_fecha_proceso) - 1
        ORDER BY pa.fecha_venc_pago, p.apaterno;
    
    -- UTILIZACION DE REGISTRO PARA ENCAPSULAR UN CONJUNTO DE VARIABLES 
    -- SE UTILIZA reg_pac cur_multa%ROWTYPE EN DONDE YA ESTAN ENCAPSULADOS LOS TYPE DEL CURSOR
    TYPE type_paciente_deuda IS RECORD(
        reg_pac cur_multa%ROWTYPE,
        nombre_completo_pac VARCHAR2(50), 
        pac_edad NUMBER,
        desc_tercera_edad NUMBER, 
        dias_morosidad NUMBER,
        mult_esp NUMBER,
        monto_multa NUMBER);
    
    v_pac_reg_deuda type_paciente_deuda; 
    
    v_contador NUMBER := 0; 
    
    -- DECLARACIÓN VARRAY
    TYPE varray_multas IS VARRAY(50) OF NUMBER; 
    va_multas varray_multas := varray_multas();
    
    

BEGIN 
    
    --TRUNCADO TABLE PAGO_MOROSO
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pago_moroso';
    
    -- ABRE EL CURSOR
    OPEN cur_multa; 
    
    -- POR MEDIO DEL LOOP-FETCH SE OBTIENE UNA FILA DEL CURSOR QUE SE ALMACENA EN LA VARIABLE v_pac_reg_deuda.reg_pac SITUADA EN EL RECORD
    LOOP
        FETCH cur_multa INTO v_pac_reg_deuda.reg_pac;             
        EXIT WHEN cur_multa%NOTFOUND;
        
        --LOGICA CENTRAL DEL CASO 
        v_pac_reg_deuda.nombre_completo_pac := v_pac_reg_deuda.reg_pac.pnombre || ' ' || 
                                               v_pac_reg_deuda.reg_pac.snombre || ' ' || 
                                               v_pac_reg_deuda.reg_pac.apaterno || ' ' || 
                                               v_pac_reg_deuda.reg_pac.amaterno;
                                               
        v_pac_reg_deuda.dias_morosidad := v_pac_reg_deuda.reg_pac.fecha_pago - v_pac_reg_deuda.reg_pac.fecha_venc_pago;
        v_pac_reg_deuda.pac_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_pac_reg_deuda.reg_pac.fecha_nacimiento)/12);
        
        v_pac_reg_deuda.desc_tercera_edad := 
            CASE
                WHEN v_pac_reg_deuda.pac_edad < 65 THEN 1
                WHEN v_pac_reg_deuda.pac_edad BETWEEN 65 AND 70 THEN 0.98
                WHEN v_pac_reg_deuda.pac_edad BETWEEN 71 AND 75 THEN 0.95
                WHEN v_pac_reg_deuda.pac_edad BETWEEN 76 AND 80 THEN 0.92
                WHEN v_pac_reg_deuda.pac_edad BETWEEN 81 AND 85 THEN 0.9
                WHEN v_pac_reg_deuda.pac_edad BETWEEN 86 AND 120 THEN 0.8
            END;
            
        v_pac_reg_deuda.mult_esp :=  
            CASE
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 100 OR v_pac_reg_deuda.reg_pac.esp_id = 300 THEN 1200
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 200 THEN  1300
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 400 OR v_pac_reg_deuda.reg_pac.esp_id = 900 THEN 1700
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 500 OR v_pac_reg_deuda.reg_pac.esp_id = 600 THEN 1900
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 700 THEN 1100
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 1100 THEN 2000
                WHEN v_pac_reg_deuda.reg_pac.esp_id = 1400 OR v_pac_reg_deuda.reg_pac.esp_id = 1800 THEN 2300   
            END; 
            
        v_pac_reg_deuda.monto_multa := (v_pac_reg_deuda.mult_esp * v_pac_reg_deuda.dias_morosidad) * v_pac_reg_deuda.desc_tercera_edad;   
       
        -- INSERTAN VALORES EN TABLA PAGO_MOROSO
        INSERT 
        INTO pago_moroso(
                         pac_run, 
                         pac_dv_run, 
                         pac_nombre, 
                         ate_id, 
                         fecha_venc_pago, 
                         fecha_pago, 
                         dias_morosidad, 
                         especialidad_atencion, 
                         monto_multa) 
        VALUES(
                         v_pac_reg_deuda.reg_pac.pac_run, 
                         v_pac_reg_deuda.reg_pac.dv_run, 
                         v_pac_reg_deuda.nombre_completo_pac, 
                         v_pac_reg_deuda.reg_pac.ate_id, 
                         v_pac_reg_deuda.reg_pac.fecha_venc_pago, 
                         v_pac_reg_deuda.reg_pac.fecha_pago, 
                         v_pac_reg_deuda.dias_morosidad, 
                         v_pac_reg_deuda.reg_pac.nombre, 
                         v_pac_reg_deuda.monto_multa);       
        
        -- CONTADOR RESPALDA LAS ITERACIONES DEL LOOP
        v_contador := v_contador + 1; 
        
        -- EXTEND crea un nuevo espacio en el VARRAY
        -- El CONTADOR es el índice (posición) donde se guarda el valor
        -- Se asigna el valor de la multa a esa posición 
        va_multas.EXTEND; 
        va_multas(v_contador) := v_pac_reg_deuda.monto_multa;
              
        DBMS_OUTPUT.PUT_LINE('RUT: ' || v_pac_reg_deuda.reg_pac.pac_run || '-' || v_pac_reg_deuda.reg_pac.dv_run);
        DBMS_OUTPUT.PUT_LINE('NOMBRE: ' || v_pac_reg_deuda.nombre_completo_pac);
        DBMS_OUTPUT.PUT_LINE('DIAS MOROSIDAD: ' || v_pac_reg_deuda.dias_morosidad);
        DBMS_OUTPUT.PUT_LINE('EDAD: ' || v_pac_reg_deuda.pac_edad);
        DBMS_OUTPUT.PUT_LINE('DESCUENTO: ' || v_pac_reg_deuda.desc_tercera_edad);
        DBMS_OUTPUT.PUT_LINE('MULTIPLICADOR: ' || v_pac_reg_deuda.mult_esp);
        DBMS_OUTPUT.PUT_LINE('DEUDA TOTAL: ' || v_pac_reg_deuda.monto_multa);
        DBMS_OUTPUT.PUT_LINE('NOMBRE ESPECIALIDAD: ' || v_pac_reg_deuda.reg_pac.nombre); 
        DBMS_OUTPUT.PUT_LINE('');             
    END LOOP;
    
        DBMS_OUTPUT.PUT_LINE('Total multas en VARRAY: ' || va_multas.COUNT);
    
    CLOSE cur_multa;
    
    -- COMMIT POR MEDIO DE IF CON UTILIZACIÓN DE CONTADOR
    IF v_contador > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Se cargaron ' || v_contador || ' registros de multas.');
        DBMS_OUTPUT.PUT_LINE('Total multas en VARRAY: ' || va_multas.COUNT);
    
    -- ELSE QUE PROCESA UN ROLLBACK     
    ELSE
        ROLLBACK TO SAVEPOINT sp_pago_moroso;
        DBMS_OUTPUT.PUT_LINE('No hay registros para procesar.');
    END IF;
    
END;
/


--======================================
-- EXP 2 SEMANA 3 : CASO 2
--======================================

SAVEPOINT sp_medico_servicio_comunidad; 

--ELIMINACION Y CREACION DE TABLA medico_servicio_comunidad
DROP TABLE MEDICO_SERVICIO_COMUNIDAD; 

CREATE TABLE MEDICO_SERVICIO_COMUNIDAD
(id_med_scomun NUMBER(2) GENERATED ALWAYS AS IDENTITY MINVALUE 1 
MAXVALUE 9999999999999999999999999999
INCREMENT BY 1 START WITH 1
CONSTRAINT PK_MED_SERV_COMUNIDAD PRIMARY KEY,
 unidad VARCHAR2(50) NOT NULL,
 run_medico VARCHAR2(15) NOT NULL,
 nombre_medico VARCHAR2(50) NOT NULL,
 correo_institucional VARCHAR2(25) NOT NULL,
 total_aten_medicas NUMBER(2) NOT NULL,
 destinacion VARCHAR2(50) NOT NULL);


-- VARIABLE BIND PARA ALMACENAR EL VALOR DE ATENCIONES MAXIMAS
VAR b_maximo_atenciones NUMBER; 
EXEC :b_maximo_atenciones := 0; 

DECLARE
    --CURSOR QUE PERMITE EXTRAER EL VALOR DE ATENCIONES MAXIMA
    CURSOR cur_maximo_atenciones IS 
        SELECT
            COUNT(a.ate_id)
        FROM medico m
        LEFT JOIN atencion a ON m.med_run = a.med_run
            AND EXTRACT(YEAR FROM a.fecha_atencion) = EXTRACT(YEAR FROM :b_fecha_proceso) - 1
        GROUP BY 
            m.med_run;           
    v_maximo_atenciones NUMBER; 
    
BEGIN
    
    --ABRE CURSOS
    OPEN cur_maximo_atenciones;
    LOOP 
        FETCH cur_maximo_atenciones INTO v_maximo_atenciones;
        EXIT WHEN cur_maximo_atenciones%NOTFOUND;
        
        -- SE REEMPLAZA EL VALOR DE LA VARIABLE BIND SI LA VARIABLE OBETENIDA
        -- DE LA ITERACION DEL CURSOR ES MAYOR
        IF v_maximo_atenciones > :b_maximo_atenciones THEN
            :b_maximo_atenciones := v_maximo_atenciones;  
        END IF;
    
    END LOOP; 
    CLOSE cur_maximo_atenciones; 
    
    DBMS_OUTPUT.PUT_LINE('MAXIMO ATENCIONES: ' || :b_maximo_atenciones);
    DBMS_OUTPUT.PUT_LINE('');
END; 
/

-- BLOQUE PL/SQL PRINCIPAL
DECLARE
    -- DECLARACION DE CURSOR
    CURSOR cur_med_sc IS
        SELECT
            u.nombre AS unidad,
            u.uni_id,
            m.med_run,
            m.dv_run,
            m.pnombre,
            m.snombre,
            m.apaterno,
            m.amaterno,
            COUNT(a.ate_id) AS total_atenciones
        FROM medico m
        INNER JOIN unidad u ON m.uni_id = u.uni_id
        LEFT JOIN atencion a ON a.med_run = m.med_run
            AND EXTRACT(YEAR FROM a.fecha_atencion) = EXTRACT(YEAR FROM :b_fecha_proceso) - 1
        GROUP BY
            u.nombre,
            u.uni_id,
            m.med_run,
            m.dv_run,
            m.pnombre,
            m.snombre,
            m.apaterno,
            m.amaterno
        ORDER BY u.nombre, m.apaterno    
;    

    -- UTILIZACIÓN DE RECORD
    TYPE type_med_reg IS RECORD(
        med_reg cur_med_sc%ROWTYPE,
        med_nombre_completo VARCHAR2(50),
        correo_inst VARCHAR2(25),
        destinacion VARCHAR2(50) 
    );
    
    -- VARIABLE DE TYPE RECORD
    v_med_reg type_med_reg;
    
    v_maximo_atenciones NUMBER := 0;   
    v_contador NUMBER := 0;
    
    -- VARRAY 
    TYPE varray_med_destinaciones IS VARRAY(100) OF VARCHAR2(50);
    va_med_destinaciones varray_med_destinaciones := varray_med_destinaciones();   

BEGIN

    --TRUNCADO DE TABLA MEDICO_SERVICIO_COMUNIDAD
    EXECUTE IMMEDIATE 'TRUNCATE TABLE medico_servicio_comunidad'; 
    
    -- SE ABRE EL CURSOR
    OPEN cur_med_sc;
    
    -- LOOP CURSOR    
    LOOP
        -- SE TOMA UNA FILA DEL CURSOR Y SE LA VINCULA A LA VARIABLE v_med_reg.med_reg DEL RECORD 
        FETCH cur_med_sc INTO v_med_reg.med_reg;
        EXIT WHEN cur_med_sc%NOTFOUND;
        
        --LOGICA CASO PLANTEADO
        IF v_med_reg.med_reg.total_atenciones < :b_maximo_atenciones THEN
            
            -- NOMBRE COMPLETO MEDICO
            v_med_reg.med_nombre_completo := v_med_reg.med_reg.pnombre || ' ' ||
                                             v_med_reg.med_reg.snombre || ' ' ||
                                             v_med_reg.med_reg.apaterno || ' ' ||
                                             v_med_reg.med_reg.amaterno;
            
            -- DESTINACION MEDICO
            v_med_reg.destinacion := 
            
                -- CASE PRINCIPAL
                CASE
                    -- CASE CON SOLO 1 CONDICION 
                    WHEN v_med_reg.med_reg.uni_id IN (100,400) 
                        THEN 'Servicio de Atención Primaria de Urgencia (SAPU)'
                    WHEN v_med_reg.med_reg.uni_id IN (300, 500,900)
                       THEN 'Hospitales del área de la Salud Pública'
                    WHEN v_med_reg.med_reg.uni_id = 600
                       THEN 'Centros de Salud Familiar (CESFAM)'
                       
                    --CASE CON DOBLE CONDICION NUMERO ANTENCIONES 0-3       
                    WHEN v_med_reg.med_reg.total_atenciones BETWEEN 0 AND 3 
                        THEN
                            CASE
                                WHEN v_med_reg.med_reg.uni_id IN (200,700,800,1000) 
                                    THEN 'Servicio de Atención Primaria de Urgencia (SAPU)'
                            END
                            
                    --CASE CON DOBLE CONDICION NUMERO ANTENCIONES >3                         
                    WHEN v_med_reg.med_reg.total_atenciones > 3
                        THEN
                            CASE
                                WHEN v_med_reg.med_reg.uni_id IN (200,700,800,1000)
                                    THEN 'Hospitales del área de la Salud Pública'
                            END                                              
                END
                --CIERRE CASE PRINCIPAL
                ;
                
            -- CORREO INSTITUCIONAL
            v_med_reg.correo_inst := SUBSTR(v_med_reg.med_reg.unidad,1,2) ||
                                     SUBSTR(v_med_reg.med_reg.apaterno,-3,1) ||
                                     SUBSTR(v_med_reg.med_reg.apaterno,-2,1)||
                                     SUBSTR(TO_CHAR(v_med_reg.med_reg.med_run),-3)|| 
                                     '@medicocktk.cl';
                               
            DBMS_OUTPUT.PUT_LINE('NOMBRE MEDICO: ' || v_med_reg.med_nombre_completo);    
            DBMS_OUTPUT.PUT_LINE('DESTINACION: ' || v_med_reg.destinacion);
            DBMS_OUTPUT.PUT_LINE('CORREO INSTITUCIONAL: ' || v_med_reg.correo_inst);
            DBMS_OUTPUT.PUT_LINE(' ');
            
            --INSERT DE DATOS EN TABLA medico_servicio_comunidad
            INSERT INTO medico_servicio_comunidad(
                                                  unidad,
                                                  run_medico,
                                                  nombre_medico,
                                                  correo_institucional,
                                                  total_aten_medicas,
                                                  destinacion) 
            VALUES(
                                                  v_med_reg.med_reg.unidad,
                                                  TO_CHAR(v_med_reg.med_reg.med_run, '09G999G999') || '-' || v_med_reg.med_reg.dv_run,
                                                  v_med_reg.med_nombre_completo,
                                                  v_med_reg.correo_inst,
                                                  v_med_reg.med_reg.total_atenciones,
                                                  v_med_reg.destinacion);
            
            -- CONTADOR DE ITERACIONES
            v_contador := v_contador +1;
            
            -- EXTEND crea un nuevo espacio en el VARRAY
            -- El CONTADOR es el índice (posición) donde se guarda el valor
            -- Se asigna el valor de la DESTINACION a esa posición 
            va_med_destinaciones.EXTEND; 
            va_med_destinaciones(v_contador) := v_med_reg.destinacion;
        
        -- CIERRE DE LOGICA PRINCIPAL    
        END IF; 
    
    -- CIERRE LOOP-FETCH CURSOR     
    END LOOP; 
    
    --CIERRE CURSOR
    CLOSE cur_med_sc;
    
    -- COMMIT POR MEDIO DE IF CON UTILIZACIÓN DE CONTADOR 
    IF v_contador > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Se cargaron ' || v_contador || ' registros en la tabla MEDICO_SERVICIO_COMUNIDAD.');
        DBMS_OUTPUT.PUT_LINE('Total destinaciones en VARRAY: ' || va_med_destinaciones.COUNT);
    
    -- ELSE QUE PROCESA UN ROLLBACK AL SAVEPOINT     
    ELSE
        ROLLBACK TO SAVEPOINT sp_medico_servicio_comunidad;
        DBMS_OUTPUT.PUT_LINE('No hay registros para procesar.');
    END IF;
    
END; 
/

