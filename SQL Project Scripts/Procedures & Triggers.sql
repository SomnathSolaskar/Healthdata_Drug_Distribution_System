/*
************************************************************************
************************************************************************
* Author : Somnath Solaskar                                            *
*                                                                      *
* Scope   : Stored Procedures, Triggers & Functions with File          *
*			Error Handling                                 *
*								       *
* Content: Insert Patient --> Contact --> Case --> Prescrip	       *
*		  --> Presc_medicines -->Claims --> Claim Approval     *
*		  --> Orders --> Order Status			       *
*								       *
* Date   : 12-28-2021						       *
************************************************************************
************************************************************************
*/
------------------------------------------------------------------------
--              PROC INSERT NEW PATIENT
------------------------------------------------------------------------
create or replace PROCEDURE ins_patient (
    in_first_name       IN VARCHAR2,
    in_last_name        IN VARCHAR2,
    in_gender           IN VARCHAR2,
    in_ssn              IN VARCHAR2,
    in_client_name      IN VARCHAR2,
    in_date_of_birth    IN DATE,
    in_insurance_status IN VARCHAR2
) AS

    var_client_id  NUMBER;
    var_date_check VARCHAR2(100);
    var_pat_cnt    NUMBER;
    cntssn         NUMBER := 0;
    unique_pat_id EXCEPTION;
    first_name_invalid EXCEPTION;
    last_name_invalid EXCEPTION;
    date_of_birth_invalid EXCEPTION;
    date_of_birth_invalid_1 EXCEPTION;
    gender_invalid EXCEPTION;
    ssn_unique EXCEPTION;
    client_name_invalid EXCEPTION;
    insurance_status_invalid EXCEPTION;
    client_not_found EXCEPTION;
    ssn_invalid_chars EXCEPTION;
    ssn_mal_formed EXCEPTION;
    ssn_null EXCEPTION;
    future_date EXCEPTION;
BEGIN
    IF in_client_name IS NULL OR VALIDATE_CONVERSION ( TRIM(in_client_name) AS NUMBER ) = 1 THEN
        RAISE client_name_invalid;
    ELSE
        BEGIN
            SELECT
                client_id
            INTO var_client_id
            FROM
                client
            WHERE
                    upper(TRIM(client_name)) = upper(TRIM(in_client_name))
                AND status = 'Active'
                AND is_deleted IS NULL;

        EXCEPTION
            WHEN no_data_found THEN
                RAISE client_not_found;
        END;
    END IF;

    IF in_ssn IS NULL THEN
        RAISE ssn_null;
    ELSIF regexp_instr(in_ssn, '^[0-9\-]*$') = 0 THEN
        RAISE ssn_invalid_chars;
    ELSIF regexp_instr(in_ssn, '^[0-9]{3}-[0-9]{2}-[0-9]{4}*$') = 0 THEN
        RAISE ssn_mal_formed;
    ELSIF in_ssn IS NOT NULL THEN
        SELECT
            COUNT(*)
        INTO cntssn
        FROM
            patient
        WHERE
                ssn = in_ssn
            AND is_deleted IS NULL;

        IF ( cntssn > 0 ) THEN
            RAISE ssn_unique;
        ELSE
            dbms_output.put_line('valid ssn');
        END IF;

    END IF;

    IF in_first_name IS NULL OR VALIDATE_CONVERSION ( in_first_name AS NUMBER ) = 1 THEN
        RAISE first_name_invalid;
    ELSIF
        regexp_like(in_first_name, '[[:alpha:]]')
        AND regexp_instr(in_first_name, '[0-9]') > 0
    THEN
        RAISE first_name_invalid;
    ELSIF in_last_name IS NULL OR VALIDATE_CONVERSION ( in_last_name AS NUMBER ) = 1 THEN
        RAISE last_name_invalid;
    ELSIF
        regexp_like(in_last_name, '[[:alpha:]]')
        AND regexp_instr(in_last_name, '[0-9]') > 0
    THEN
        RAISE last_name_invalid;
    ELSIF in_gender IS NULL OR upper(in_gender) NOT IN ( 'M', 'F', 'O' ) THEN
        RAISE gender_invalid;
    ELSIF in_date_of_birth IS NULL THEN
        RAISE date_of_birth_invalid;
    ELSIF date_check(in_date_of_birth) = 2 THEN
        RAISE future_date;
    ELSE
        SELECT
            COUNT(*)
        INTO var_pat_cnt
        FROM
            patient
        WHERE
                TRIM(first_name) = TRIM(in_first_name)
            AND TRIM(last_name) = TRIM(in_last_name)
            AND TRIM(gender) = TRIM(in_gender)
            AND TRIM(date_of_birth) = TRIM(in_date_of_birth)
            AND is_deleted IS NULL;

    END IF;

    IF ( var_pat_cnt > 0 ) THEN
        RAISE unique_pat_id;
    ELSIF in_insurance_status IS NULL THEN
        RAISE insurance_status_invalid;
    ELSIF upper(in_insurance_status) NOT IN ( 'INSURED', 'UNINSURED' ) THEN
        RAISE insurance_status_invalid;
    ELSE
        INSERT INTO patient (
            patient_id,
            first_name,
            last_name,
            patient_number,
            date_of_birth,
            gender,
            ssn,
            client_id,
            insurance_status,
            updated_date,
            created_date,
            is_deleted,
            delete_date,
            flag
        ) VALUES (
            sequence_primary_id.NEXTVAL,
            initcap(in_first_name),
            initcap(in_last_name),
            sequence_primary_id.NEXTVAL,
            in_date_of_birth,
            in_gender,
            in_ssn,
            var_client_id,
            initcap(in_insurance_status),
            sysdate,
            sysdate,
            NULL,
            NULL,
            'INS'
        );

        dbms_output.put_line('Patient is added');
        COMMIT;
    END IF;

EXCEPTION
    WHEN unique_pat_id THEN
        raise_application_error(-20001, 'Patient already exists in Database');
    WHEN first_name_invalid THEN
        raise_application_error(-20002, 'First Name is NUll or Invalid');
    WHEN last_name_invalid THEN
        raise_application_error(-20003, 'Last Name is NUll or Invalid');
    WHEN gender_invalid THEN
        raise_application_error(-20004, 'Gender should be M,F or O');
    WHEN ssn_unique THEN
        raise_application_error(-20005, 'SSN is NOT unique');
    WHEN date_of_birth_invalid THEN
        raise_application_error(-20006, 'Date of Birth is Invalid');
    WHEN client_name_invalid THEN
        raise_application_error(-20007, 'Client Name is Null or Invalid');
    WHEN insurance_status_invalid THEN
        raise_application_error(-20008, 'Insurance status should be Insured or Uninsured');
    WHEN client_not_found THEN
        raise_application_error(-20009, 'Client not found in database');
    WHEN ssn_invalid_chars THEN
        raise_application_error(-20011, 'SSN has invalid characters');
    WHEN ssn_mal_formed THEN
        raise_application_error(-20012, 'Mal-formed SSN  Number');
    WHEN ssn_null THEN
        raise_application_error(-20013, 'SSN  Number should not be null');
    WHEN future_date THEN
        raise_application_error(-20014, 'Date of Birth cannot be a future date');
        COMMIT;
END;
/

--------------------------------------------------------------
--                   PROC INSERT PATIENT CONTACT
--------------------------------------------------------------

create or replace PROCEDURE ins_pat_contact (
    in_patient_id   IN NUMBER,
    in_address      IN VARCHAR2,
    in_city         IN VARCHAR2,
    in_state        IN VARCHAR2,
    in_postal_code  IN VARCHAR2,
    in_phone_type   IN VARCHAR2, -- Not Mandatory
    in_phone_number IN VARCHAR2
) AS

    var_patient_id NUMBER :=0;
    var_pat_cnt    NUMBER :=0;
	con_patient_id NUMBER :=0;
    unique_pat_id EXCEPTION;
    address_invalid EXCEPTION;
    city_invalid EXCEPTION;
    state_invalid EXCEPTION;
    postal_code_invalid EXCEPTION;
    phone_type_invalid EXCEPTION;
    phone_number_invalid EXCEPTION;
    phone_length_invalid EXCEPTION;
	pATIENT_id_NULL EXCEPtion;
	patient_not_found EXCEPTION;
	PATIENT_CONTACT_EXIST EXCEPTION;
    state_alpha exception;

BEGIn
    IF in_address IS NULL THEN
        RAISE address_invalid;
    ELSIF in_city IS NULL THEN
        RAISE city_invalid;
	ELSIf
		regexp_like(in_city, '[[:alpha:]]')
        AND regexp_instr(in_city, '[0-9]') > 0
    THEN
        RAISE city_invalid;
    ELSIF in_state IS NULL OR VALIdate_CONVErsion(IN_STate As numBER)=1 THEN
        RAISE state_invalid;
    ELSIF
        length(in_state) != 2
    THEN
        RAISE state_invalid;
	ELSIf
		regexp_like(in_state, '[[:alpha:]]')
        AND regexp_instr(in_state, '[0-9]') > 0
    THEN
        RAISE state_alpha;
    ELSIF in_postal_code IS NULL THEN
        RAISE postal_code_invalid;
    ELSIF VALIDATE_CONVERSION ( in_postal_code AS NUMBER ) = 0 THEN
       RAISE postal_code_invalid;
    ELSIF length(in_postal_code) <> 5 THEN
        RAISE postal_code_invalid;
    ELSIF in_phone_type IS NULL THEN
        RAISE phone_type_invalid;
    ELSIF
        in_phone_type IS NOT NULL
        AND upper(in_phone_type) NOT IN ( 'HOME', 'MOBILE', 'OFFICE' )
    THEN
        RAISE phone_type_invalid;
    ELSIF in_phone_number IS NULL THEN
        RAISE phone_number_invalid;
    ELSIF length(in_phone_number) <> 10 THEN
        RAISE phone_length_invalid;
    ELSIF VALIDATE_CONVERSION ( in_phone_number AS NUMBER ) = 0 THEN
        RAISE phone_number_invalid;
    ELSE DBMS_OUTPUT.PUT_LINE('');
	end if;

	IF in_patient_id IS NUll  then
		RAISe pATIENT_id_NULL;
    ELSE
        BEGIN
            SELECT
            COUNT(*)
        INTO var_patient_id
        FROM
            patient
        WHERE
            patient_id = in_patient_id and is_deleted is null;

        EXCEPTION
            WHEN no_data_found THEN
                RAISE patient_not_found;
        END;
    END IF;


        SELECT
            COUNT(*)
        INTO con_patient_id
        FROM
            contact
        WHERE
            patient_id = in_patient_id and is_deleted is null and upper(phone_type)=upper(in_phone_type);


    IF var_patient_id > 0 and con_patient_id=0 THEN
            INSERT INTO contact VALUES (
                sequence_primary_id.NEXTVAL,
                in_patient_id,
                in_address,
                initcap(in_city),
                upper(in_state),
                in_postal_code,
                initcap(in_phone_type),
                in_phone_number,
                sysdate,
                sysdate,
                NULL,
                NULL
            );
			COMMIT;
		ELSE RAISE PATIENT_CONTACT_EXIST;
        END IF;

EXCEPTION
    WHEN patient_not_found THEN
        raise_application_error(-20001, 'Patiet doesn''t exist in Database');
    WHEN address_invalid THEN
        raise_application_error(-20002, 'Address should not be null or Invalid');
    WHEN city_invalid THEN
        raise_application_error(-20003, 'City should not be NUll or invalid');
    WHEN state_invalid THEN
        raise_application_error(-20004, 'State should not be NUll or number and length must be 2');
    WHEN postal_code_invalid THEN
        raise_application_error(-20005, 'Postal Code should not be Null and must be 5 digits');
    WHEN phone_type_invalid THEN
        raise_application_error(-20006, 'Phone type should be Mobile, Home or Office');
    WHEN phone_number_invalid THEN
        raise_application_error(-20007, 'Phone Number should not be Null or invalid');
    WHEN phone_length_invalid THEN
        raise_application_error(-20008, 'Phone Number length must be 10');
    WHEN PATIENT_CONTACT_EXIST THEN
        raise_application_error(-20009, 'Patient with this contact type already exist');
	WHEN pATIENT_id_NULL THEN
        raise_application_error(-20010, 'Patient_id is null');
    WHEN state_alpha THEN
        raise_application_error(-20010, 'PState should be characters');


        COMMIT;
END;
/

--------------------------------------------------------------
--                   PROC INSERT NEW CASE
--------------------------------------------------------------
create or replace TRIGGER trg_ins_case AFTER
    INSERT ON patient
    FOR EACH ROW
BEGIN
    INSERT INTO case VALUES (
        sequence_primary_id.NEXTVAL,
        'New',
        :new.patient_id,
        sysdate,
        sysdate,
        NULL,
        NULL
    );

END;

--------------------------------------------------------------
--                   PROC INSERT NEW PRESCRIPTION
--------------------------------------------------------------

create or replace PROCEDURE ins_pat_prescription (
    in_Case_ID      IN NUMBER,
    in_disease_name         IN VARCHAR2,
    in_disease_type        IN VARCHAR2
) AS
	cnt_medicine_id number;
	var_medicine_id number;
	var_CASE_id NUMBer;
	CASE_ID_INVALID EXCEPTION;
	CASE_ID_NAD EXCEPTION;
    disease_name_null EXCEPTION;

    BEGIN
        IF in_case_id IS NULL THEN
            RAISE case_id_invalid;
        ELSIF in_disease_name IS NULL THEN
            RAISE disease_name_null;
        ELSE
            dbms_output.put_line('Null check passed');
        END IF;

    SELECT
        COUNT(*)
    INTO var_case_id
    FROM
        case
    WHERE
        case_id = in_case_id;

    IF var_case_id = 1 THEN
        dbms_output.put_line('Case is found in database, Creating prescription');
        INSERT INTO prescription VALUES (
            sequence_primary_id.NEXTVAL,
            in_case_id,
            initcap(in_disease_name),
            initcap(in_disease_type),
            sysdate,
            sysdate,
            NULL,
            NULL
			);
        COMMIT;
		else
		raise case_id_nad;
    END IF;
EXCEPTION
    WHEN disease_name_null THEN
        raise_application_error(-20001, 'Disease name is required');
    WHEN CASE_ID_INVALID THEN
        raise_application_error(-20002, 'Case id should not be null or invalid');
	WHEN CASE_ID_NAD THEN
        raise_application_error(-20003, 'Please Create the Case first');

    COMMIT;
END;
/

--------------------------------------------------------------
--                   PROC PRESCRIBED MEDICINES
--------------------------------------------------------------

create or replace PROCEDURE ins_prescription_medicine (
    in_Prescription_ID      IN NUMBER,
	in_medicine_name  in varchar2,
	in_Manufacturer in varchar2,
	in_quantity in number,
	in_strength in varchar2
) AS
	cnt_medicine_id number :=0;
	var_medicine_id number;
	cnt_presc_id number :=0;
	prescription_null eXCEPTIon;
	medicine_name_null exception;
	manufacturer_null exception;
	quantity_null exception;
	strength_null exception;
	presc_not_available exception;
	--medicine_name_NAD exception;
    BEGIN
		if in_Prescription_ID is null then
		raise prescription_null;
        ELsIF in_medicine_name IS NULL THEN
            RAISE medicine_name_null;
        ELSIF in_manufacturer IS NULL THEN
            RAISE manufacturer_null;
        ELSIF in_quantity IS NULL THEN
            RAISE quantity_null;
        ELSIF in_strength IS NULL THEN
            RAISE strength_null;
        ELSE
            dbms_output.put_line('');
        END IF;

		SELECT
        COUNT(*)
        INTO cnt_presc_id
        FROM
            prescription
        WHERE
                prescription_id = in_prescription_id;
		if cnt_presc_id=0 then
		raise presc_not_available;
		end if;

        SELECT
             COUNT(*)
        INTO cnt_medicine_id
        FROM
            medicines
        WHERE
                upper(trim(medicine_name)) = upper(trim(in_medicine_name))
            AND upper(manufacturer) = upper(in_manufacturer)
                AND upper(trim(strength)) = upper(trim(in_strength)) AND IS_DELETED is null;

    IF ( cnt_medicine_id > 0 ) THEN
        SELECT
            medicine_id into
         var_medicine_id
        FROM
            medicines 
        WHERE rownum=1 and 
                medicine_name = (SELECT DISTINCT MEDICINE_NAME FROM MEDICINES WHERE UPPER(TRIM(MEDICINE_NAME))=UPPER(TRIM(in_medicine_name)) AND upper(trim(manufacturer)) = upper(TRIM(in_manufacturer))
			 AND upper(trim(strength)) = upper(trim(in_strength)) and is_deleted is null) ;

		dbms_output.put_line('Medicine found in approved list');
    ELSE
        dbms_output.put_line('Medicine not available in approved list, added to prescription');
    END IF;

    IF cnt_medicine_id >0 or  cnt_medicine_id=0 
	THEN
        INSERT INTO presc_medicine (
            order_med_id,
            prescription_id,
            medicine_id,
            quantity,
            strength,
            created_date,
            updated_date
        ) VALUES (
            sequence_next_key.NEXTVAL,
            in_prescription_id,
            var_medicine_id,
            in_quantity,
            in_strength,
            sysdate,
            sysdate
        );
        COMMIT;
		else
		dbms_output.put_line('Rows not inserted');
    END IF;
EXCEPTION
	when prescription_null then
		raise_application_error(-20004, 'Prescription Name should not be null');
	WHEN medicine_name_null THEN
        raise_application_error(-20005, 'Medicine Name should not be null');
	WHEN manufacturer_null THEN
        raise_application_error(-20006, 'manufacturer should not be null');
	WHEN quantity_null THEN
        raise_application_error(-20007, 'quantity should not be null');
	WHEN strength_null THEN
        raise_application_error(-20008, 'strength should not be null');
	WHEN presc_not_available then
        raise_application_error(-20009, 'Prescription is not available in database');
    COMMIT;
END;
/

--------------------------------------------------------------
--                 FUNCTION GET CLIENT ID FOR PATIENT
--------------------------------------------------------------
create or replace FUNCTION get_pat_client_id(i_case_id in number) RETURN NUMBER IS
        cli_id NUMBER;
    BEGIN
        SELECT
            cl.client_id
        INTO cli_id
        FROM
            client cl
        WHERE cl.client_id = (select p.client_id from patient p where patient_id= (select patient_id from case where case_id=i_case_id))
                ;

        RETURN cli_id;
    END get_pat_client_id;
/
--------------------------------------------------------------
--                   TRIGGER GENERATE CLAIMS
--------------------------------------------------------------

create or replace TRIGGER trg_ins_claims AFTER
    INSERT ON prescription
    FOR EACH ROW
BEGIN
    INSERT INTO claims VALUES (
        sequence_claim_id.NEXTVAL,
        'Claim Requested',
		'New',
		get_pat_client_id(:new.case_id),
		:new.prescription_id,
        sysdate,
        sysdate,
        NULL,
        NULL
    );
END;
/

--------------------------------------------------------------
--                   FUNCTION ALLOCATE_PHARMACY
--------------------------------------------------------------

create or replace FUNCTION allocate_pharmacy(in_cLIENT_id NUMber)
	
		RETURN number IS
		pharma_id number;
    BEGIN
        IF In_cLIENT_id IN (1,4,6,8) then
		pharma_id :=64639;
		elsif In_cLIENT_id in (11,12,13,14) then
		pharma_id :=47322;
		elsif In_cLIENT_id in (15,16,18,19) then
		pharma_id :=46947;
		elsif In_cLIENT_id in (20,21,24) then
		pharma_id :=62012;
		else 
		SELECT pharmacy_id into pharma_id FROM pharmacy SAMPLE(1) where rownum=1 and UPPER(STATUS)='ACTIVE' and is_deleted is null;
		end if;
        RETURN pharma_id;
    END allocate_pharmacy;
--------------------------------------------------------------
--                   PROC CLAIMS APPROVAL
--------------------------------------------------------------

create or replace PROCEDURE claims_approval (
    in_client_id       IN NUMBER,
    in_prescription_id IN NUMBER,
    in_claim_id        IN NUMBER
) AS

    cnt_med_id   NUMBER := 0;
    cnt_full_id  NUMBER := 0;
    cnt_id_check NUMBER := 0;
    cl_status    VARCHAR2(255);
    client_id_null EXCEPTION;
    prescription_id_null EXCEPTION;
    claim_id_null EXCEPTION;
    wrong_id_comb EXCEPTION;
    cl_staus_not_valid EXCEPTION;
BEGIN
    IF in_client_id IS NULL THEN
        RAISE client_id_null;
    ELSIF in_prescription_id IS NULL THEN
        RAISE prescription_id_null;
    ELSIF in_claim_id IS NULL THEN
        RAISE claim_id_null;
    ELSE
        dbms_output.put_line('NULL CHECK FAILED');
    END IF;

    SELECT
        COUNT(*)
    INTO cnt_id_check
    FROM
        claims
    WHERE
            claim_id = in_claim_id
        AND prescription_id = in_prescription_id
        AND client_id = in_client_id;

    IF cnt_id_check != 1 THEN
        RAISE wrong_id_comb;
    END IF;
    SELECT
        claim_status
    INTO cl_status
    FROM
        claims
    WHERE
            claim_id = in_claim_id
        AND prescription_id = in_prescription_id
        AND client_id = in_client_id;

    IF
        cnt_id_check = 1
        AND cl_status != 'New'
    THEN
        RAISE cl_staus_not_valid;
    END IF;
    WITH cte_temp1 AS (
        SELECT
            *
        FROM
            presc_medicine
        WHERE
            prescription_id = in_prescription_id
    )
    SELECT
        COUNT(*)
    INTO cnt_med_id
    FROM
        cte_temp1
    WHERE
        medicine_id IS NULL;

    WITH cte_temp2 AS (
        SELECT
            *
        FROM
            presc_medicine
        WHERE
            prescription_id = in_prescription_id
    )
    SELECT
        COUNT(*)
    INTO cnt_full_id
    FROM
        cte_temp2;

    IF
        cnt_med_id = 0
        AND cnt_full_id = 0
    THEN
        UPDATE claims
        SET
            claim_status = 'Invalid'
        WHERE
            claim_id = in_claim_id;

    ELSIF cnt_med_id = cnt_full_id THEN
        UPDATE claims
        SET
            claim_type = 'Partial',
            claim_status = 'Rejected'
        WHERE
            claim_id = in_claim_id;

    ELSIF
        cnt_med_id > 0
        AND cnt_med_id < cnt_full_id
    THEN
        UPDATE claims
        SET
            claim_type = 'Partial',
            claim_status = 'Approved'
        WHERE
            claim_id = in_claim_id;

    ELSE
        UPDATE claims
        SET
            claim_type = 'Complete',
            claim_status = 'Approved'
        WHERE
            claim_id = in_claim_id;

        COMMIT;
    END IF;

EXCEPTION
    WHEN client_id_null THEN
        raise_application_error(-20001, 'Client id should not be null');
    WHEN prescription_id_null THEN
        raise_application_error(-20002, 'Prescription is should not be null');
    WHEN claim_id_null THEN
        raise_application_error(-20003, 'Claim id should not be null');
    WHEN wrong_id_comb THEN
        raise_application_error(-20004, 'Prescription id,claims id and client id associated with each other');
    WHEN cl_staus_not_valid THEN
        raise_application_error(-20005, 'Claim status is not valid');
END;
/

--------------------------------------------------------------
--                   TRIGGER CALLING PROC CREATE ORDERS
--------------------------------------------------------------

create or replace TRIGGER trg_create_order AFTER
    UPDATE ON claims
    FOR EACH ROW
    declare
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	IF upper(:new.CLAIM_status)='APPROVED' then
	create_orders(:new.prescription_id,:new.client_id,:new.claim_status);
	else
	dbms_output.put_line('Order will not be created');
	end if;
    commit;

END;
/

--------------------------------------------------------------
--                   PROC CREATE ORDERS
--------------------------------------------------------------
create or replace PROCEDURE create_orders (
    in_Prescription_ID      IN NUMBER,
	in_client_id  in number,
	in_claim_status in varchar2
	
) AS
	cnt_medicine_id number :=0;
	var_case_id number:=0;
	var_insurance_status varchar2(255);
	prescription_null eXCEPTIon;
	Client_id_null exception;
	claim_status_null exception;
	claim_status_not_app exception;

	CURSOR pres_med IS SELECT * FROM presc_medicine where prescription_id=in_prescription_id and medicine_id is not null;
	pres_med_REC presc_medicine%ROWTYPE;

    BEGIN

		if in_claim_status != 'Approved' then
			raise claim_status_not_app;
		elsif in_Prescription_ID is null then
			raise prescription_null;
        ELsIF in_client_id IS NULL THEN
            RAISE Client_id_null;
        ELSIF in_claim_status IS NULL THEN
            RAISE claim_status_null;
		else dbms_output.put_line('');
		end if;


	select case_id into var_case_id from prescription where prescription_id=in_prescription_id;


	OPEN pres_med; 
	LOOP
    FETCH pres_med INTO pres_med_rec;
    EXIT WHEN pres_med%notfound;
    INSERT INTO orders (
        order_id,
        order_status,
        case_id,
        ship_date,
        delivery_date,
        pharmacy_id,
        created_date,
        updated_date,
        is_deleted,
        delete_date,
        order_med_id
    ) VALUES (
        sequence_next_key.nextval,
        'New',
        var_case_id,
        null,
        null,
        allocate_pharmacy(in_client_id),
        sysdate,
        sysdate,
        NULL,
        NULL,
        pres_med_rec.order_med_id
    );
	commit;
    end loop;
    CLOSE pres_med;

EXCEPTION
	when prescription_null then
		 raise_application_error(-20001, 'Prescription id should not be null');
		 when Client_id_null then
		 raise_application_error(-20002, 'Client id should not be null');
		 when claim_status_null then
		 raise_application_error(-20003, 'Claim status should not be null');
		 when claim_status_not_app then
		 raise_application_error(-20004, 'Claim is not approved');
    COMMIT;
END;
/

-----------------------------------------------------------------------------------------------------
--                   FILE HANDLING : FILTER ERROR RECORDS FROM INPUT FILE DATA
-----------------------------------------------------------------------------------------------------
--					 FUNCTION ERROR_RECORDS_TRANSFER
-----------------------------------------------------------------------------------------------------


create or replace FUNCTION error_records_transfer (
    o_id      NUMBER,
    p_id      NUMBER,
    error_txt VARCHAR
) RETURN NUMBER IS
    record_present NUMBER:=0;

    valid NUMBER := 2;

BEGIN

            SELECT
            COUNT(*)
            INTO record_present
            FROM
                error_records
            WHERE
                order_number = o_id;
    IF record_present=0 THEN

    INSERT INTO error_records (
        order_number,
        patient_number,
        error,
        err_desc,
        created_date,
        updated_date
    ) VALUES (
        o_id,
        p_id,
        error_txt,
        error_txt,
        sysdate,
        sysdate
    );

    DELETE FROM in_file
    WHERE
        order_number = o_id;
    valid := 1;
    COMMIT;

    ELSE
        DELETE FROM in_file
    WHERE
        order_number = o_id;
    valid := 2;
    COMMIT;
    END IF;

    RETURN valid;

    EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

END;
/

-----------------------------------------------------------------------------------------------------
--					 FUNCTION PAST DATE CHECK
-----------------------------------------------------------------------------------------------------

create or replace FUNCTION date_check (
    change_date IN DATE
) RETURN NUMBER IS
    valid NUMBER := 2;
BEGIN
    IF change_date <= sysdate THEN
        valid := 1;
    END IF;
    RETURN valid;
END;
/
-----------------------------------------------------------------------------------------------------
--					 PROC FILTER_ORDER_INPUTS
-----------------------------------------------------------------------------------------------------

create or replace PROCEDURE filter_order_inputs IS

    CURSOR records IS
    SELECT
        *
    FROM
        in_file;

    record_i    in_file%rowtype;
    records_to_filter NUMBER := 0;
    n_orders          NUMBER := 0;
    no_records_to_filter EXCEPTION;
    no_orders EXCEPTION;


BEGIN
    SELECT
        COUNT(*)
    INTO records_to_filter
    FROM
        in_file;

    SELECT
        COUNT(*)
    INTO n_orders
    FROM
        orders;

    IF records_to_filter = 0 THEN
        RAISE no_records_to_filter;
    ELSIF n_orders = 0 THEN
        RAISE no_orders;
    END IF;
    dbms_output.put_line('DB1');
    OPEN records;
    LOOP
        FETCH records INTO record_i;
        EXIT WHEN records%notfound;

        DECLARE
            record_present NUMBER := 0;
            flag NUMBER:=0;
            record_status VARCHAR2(255) :='NEW';
        BEGIN
            dbms_output.put_line('---BEGIN---');
            SELECT
                COUNT(*)
            INTO record_present
            FROM
                orders
            WHERE
                order_id = record_i.order_number;

                dbms_output.put_line('db8');
            BEGIN
            SELECT
                ORDER_STATUS
            INTO  record_status
            FROM
                orders
            WHERE
                order_id = record_i.order_number;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    record_status := 'New';
                END;
                            dbms_output.put_line('db9');

            IF record_i.order_number IS NULL  THEN
               dbms_output.put_line('db2');
                flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'order_number_null');
            END IF;

            IF record_i.order_status IS NULL OR upper(record_i.order_status) NOT IN ( 'SHIPPED', 'DELIVERED' ) THEN
            dbms_output.put_line('db3');
                flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'order_status_null');
                END IF;

            IF record_i.patient_number IS NULL THEN
            dbms_output.put_line('db4');
                flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'patient_number_null');
                END IF;

            IF upper(record_status) = 'DELIVERED' THEN
                flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'order_already_delivered');
            END IF;

            IF upper(record_i.order_status) = 'SHIPPED' THEN
                flag:=date_check(record_i.SHIP_DATE);
               dbms_output.put_line('---Checking SHIPPING Date---');

                IF flag = 2 THEN
                    flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'shipping_date_invalid');
                ELSE
                    flag:=status_update(record_i.order_number);
                    IF flag = 1 THEN
                        dbms_output.put_line('Order Status Updated');
                        dbms_output.put_line(record_i.order_number);
                    ELSE
                        dbms_output.put_line('Error Occured');
                    END IF;
                END IF;
            END IF;
            IF upper(record_i.order_status) = 'DELIVERED' THEN
                flag := date_check(record_i.delivery_date);
--                dbms_output.put_line('---Checking Date---');

                IF flag = 2 THEN
                    flag:=error_records_transfer(record_i.order_number,record_i.patient_number,'delivered_date_invalid');
                ELSE
                    flag:=status_update(record_i.order_number);
                    IF flag = 1 THEN
                        dbms_output.put_line('Order Status Updated');
                        dbms_output.put_line(record_i.order_number);
                    ELSE
                        dbms_output.put_line('Error Occured');
                    END IF;
                END IF;
            END IF;


        END;

    END LOOP;

EXCEPTION
    WHEN no_records_to_filter THEN
        dbms_output.put_line('---No data found in in_file table---');
    WHEN no_orders THEN
        dbms_output.put_line('---No orders data found---');
    WHEN OTHERS THEN
        dbms_output.put_line(sqlerrm);
END;
/
