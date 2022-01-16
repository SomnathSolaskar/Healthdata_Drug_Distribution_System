Runnig Queries :

set serveroutput on;
-------------------------PATIENT TABLE INSERT -------------------------------------
set serveroutput on;
exec ins_patient(in_first_name=>'Sumit',in_last_name=>'Sharma',in_gender=>'m',in_ssn=>'123-45-9820',in_client_name=>'United Health',in_date_of_birth=>'01-21-2021',in_insurance_status=>'Insured');

select * from patient order by created_date desc;

-------------------------PATIENT CONTACT INSERT -----------------------------------
set serveroutput on;
exec ins_pat_contact(in_patient_id=>1,in_address=>'463 park dr',in_city=>'Boton',in_state=>'MA',in_postal_code=>'02215',in_phone_type=>'Office',in_phone_number=>'iuytrtyuti');					

select * from contact order by created_date desc;

-------------------------CASE TABLE INSERT WITH TRIGGERS --------------------------
select * from case where patient_id='';

-------------------------PRESCRIPTION AND PRESC_MEDICINE TABLE INSERT --------------------------------

exec ins_pat_prescription(3,'disease name','disease type',2,'Pfizer',2,'13.3mg');
exec ins_pat_prescription('6','try1','try1','Trulicity','Merck & Co.','5','1.5mg/.5mL');

SET DEFINE OFF;
SET SERVEROUTPUT ON;
--exec ins_pat_prescription(3,'disease name','disease type',2,'Pfizer',2,'13.3mg');
exec ins_pat_prescription('6','try1','try1','Trulicity','Merck & Co.','5','1.5mg/.5mL');

--------------------------INSERT CLAIMS --------------------------------------------------
trg_ins_claims
get_pat_client_id
--------------------------

select * from prescription order by created_date desc;
set serveroutput on;
set define off;
exec ins_prescription_medicine(in_Prescription_ID=>500529,in_medicine_name=>'Alteryx',in_Manufacturer=>'J&J',in_quantity=>2,in_strength=>'100mg');

exec ins_prescription_medicine(in_Prescription_ID=>'tufc',in_medicine_name=>'Alteryx',in_Manufacturer=>'J&J',in_quantity=>2,in_strength=>'100mg');

----------------------------Prescription NEW-------------------------

set serveroutput on;
exec ins_pat_prescription(in_Case_ID=>5,in_disease_name=>'Ortho',in_disease_type=>'Ortho');

----------------------------Claim Approval----------------------------
exec claims_approval(in_Client_ID=>7,in_prescription_id=>1,in_claim_id=>2345);
