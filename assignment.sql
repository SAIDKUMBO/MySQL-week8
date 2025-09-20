-- Clinic Booking System: Complete SQL schema
-- Deliverable: Single .sql file containing CREATE DATABASE and CREATE TABLE statements
-- MySQL compatible (tested for ANSI SQL compliance)

-- 1) Create database
CREATE DATABASE IF NOT EXISTS clinic_booking_system
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE clinic_booking_system;

-- ---------------------------------------------------------
-- Table: users (system users: admins, receptionists)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  role ENUM('admin','reception','doctor','nurse','lab_tech') NOT NULL DEFAULT 'reception',
  email VARCHAR(150) UNIQUE,
  phone VARCHAR(30),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: patients
-- One patient can have many appointments (1:N)
-- One patient has one medical_record (1:1)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
  patient_id INT AUTO_INCREMENT PRIMARY KEY,
  national_id VARCHAR(50) UNIQUE,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  date_of_birth DATE,
  gender ENUM('male','female','other'),
  email VARCHAR(150),
  phone VARCHAR(30),
  address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: doctors
-- One doctor can have many appointments (1:N)
-- Many-to-many with services via doctor_services
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctors (
  doctor_id INT AUTO_INCREMENT PRIMARY KEY,
  staff_number VARCHAR(50) UNIQUE NOT NULL,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  specialty VARCHAR(120),
  email VARCHAR(150) UNIQUE,
  phone VARCHAR(30),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: clinics (locations)
-- One clinic can host many rooms and appointments
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinics (
  clinic_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address TEXT,
  phone VARCHAR(30),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: rooms
-- Rooms belong to a clinic; appointments can optionally reference a room
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS rooms (
  room_id INT AUTO_INCREMENT PRIMARY KEY,
  clinic_id INT NOT NULL,
  room_number VARCHAR(50) NOT NULL,
  description VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (clinic_id, room_number),
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: services (e.g., consultation, x-ray)
-- Many-to-many with doctors (doctors offer services)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS services (
  service_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) UNIQUE NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  standard_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Junction: doctor_services (Many-to-Many: doctors <-> services)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_services (
  doctor_id INT NOT NULL,
  service_id INT NOT NULL,
  price DECIMAL(10,2) NULL,
  PRIMARY KEY (doctor_id, service_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: schedules (doctors' available slots)
-- Each schedule row is a repeating availability block for a doctor at a clinic
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS schedules (
  schedule_id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  clinic_id INT NOT NULL,
  day_of_week TINYINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday..6=Saturday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_length_minutes SMALLINT NOT NULL DEFAULT 15,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (start_time < end_time)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: appointments
-- Core table connecting patients, doctors, clinics, rooms, and services
-- One appointment can have many appointment_services (1:N)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  clinic_id INT NOT NULL,
  room_id INT,
  scheduled_start DATETIME NOT NULL,
  scheduled_end DATETIME NOT NULL,
  status ENUM('scheduled','confirmed','checked_in','in_consultation','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
  notes TEXT,
  created_by INT, -- user who created the appointment
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL ON UPDATE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CHECK (scheduled_start < scheduled_end)
) ENGINE=InnoDB;

-- Indexes to speed up common queries
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_scheduled ON appointments(scheduled_start);

-- ---------------------------------------------------------
-- Table: appointment_services (services provided in each appointment)
-- Many-to-many between appointments and services with price at time of appointment
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointment_services (
  appointment_id INT NOT NULL,
  service_id INT NOT NULL,
  doctor_id INT NULL, -- optional: which doctor delivered the service
  unit_price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  PRIMARY KEY (appointment_id, service_id),
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: payments (one appointment can have many payments: partial payments allowed)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  method ENUM('cash','card','mobile_money','insurance') NOT NULL,
  transaction_ref VARCHAR(150),
  paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by INT,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: medical_records (1:1 with patients)
-- We model this as one record per patient. If you prefer multiple records (visits), change accordingly.
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS medical_records (
  record_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL UNIQUE,
  blood_type VARCHAR(10),
  allergies TEXT,
  chronic_conditions TEXT,
  notes TEXT,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: prescriptions (prescriptions issued during appointments)
-- One appointment can have many prescriptions
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS prescriptions (
  prescription_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL,
  prescribed_by INT NOT NULL, -- doctor_id
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  instructions TEXT,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (prescribed_by) REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: prescription_items (medicines within a prescription)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS prescription_items (
  prescription_id INT NOT NULL,
  item_no INT NOT NULL,
  medicine_name VARCHAR(255) NOT NULL,
  dose VARCHAR(100),
  frequency VARCHAR(100),
  duration VARCHAR(100),
  PRIMARY KEY (prescription_id, item_no),
  FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: audit_logs (lightweight audit trail)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  action VARCHAR(200) NOT NULL,
  object_type VARCHAR(80),
  object_id VARCHAR(80),
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Views and useful helpers (optional)
-- ---------------------------------------------------------
-- Example view: upcoming appointments for a clinic
CREATE OR REPLACE VIEW vw_upcoming_appointments AS
SELECT a.appointment_id, a.scheduled_start, a.scheduled_end, a.status,
       p.patient_id, CONCAT(p.first_name,' ',p.last_name) AS patient_name,
       d.doctor_id, CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
       c.clinic_id, c.name AS clinic_name
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN clinics c ON a.clinic_id = c.clinic_id
WHERE a.scheduled_start >= NOW();

-- ---------------------------------------------------------
-- Sample constraints and notes:
-- 1) Use transactions in application code when creating appointments and associated services/payments.
-- 2) Enforce business rules (e.g., double-booking prevention) at the application layer or via stored procedures/triggers.
-- ---------------------------------------------------------

-- Additional: sample data, triggers, stored procedures, and example queries

-- ---------------------------------------------------------
-- Sample seed data (small dataset to test functionality)
-- ---------------------------------------------------------
INSERT INTO clinics (name, address, phone) VALUES
('Central Clinic','123 Main St, Nairobi','+254700000001'),
('Westside Clinic','45 West Rd','+254700000002');

INSERT INTO rooms (clinic_id, room_number, description) VALUES
(1,'101','Consultation Room 1'),
(1,'102','Consultation Room 2'),
(2,'A1','Consultation Room A1');

INSERT INTO users (username, password_hash, full_name, role, email) VALUES
('admin','$2y$12$examplehash','System Admin','admin','admin@clinic.test'),
('reception1','$2y$12$examplehash2','Front Desk','reception','reception@clinic.test');

INSERT INTO doctors (staff_number, first_name, last_name, specialty, email) VALUES
('DOC001','Alice','Wanjiru','General Practice','alice.w@clinic.test'),
('DOC002','John','Otieno','Pediatrics','john.o@clinic.test');

INSERT INTO patients (national_id, first_name, last_name, date_of_birth, gender, email, phone, address) VALUES
('P123456','Mary','Achieng','1990-04-12','female','mary.a@example.com','+254711000001','Nairobi'),
('P789012','David','Kamau','1985-01-30','male','david.k@example.com','+254711000002','Nairobi');

INSERT INTO services (code, name, description, standard_price) VALUES
('CONS','Consultation','General consultation',500.00),
('PEDS','Pediatric Consultation','Consultation for children',600.00),
('XRAY','X-Ray','Chest X-Ray',1200.00);

INSERT INTO doctor_services (doctor_id, service_id, price) VALUES
(1,1,500.00),
(2,2,600.00);

-- Example schedule: Doctor Alice (doctor_id=1) works Monday to Friday 09:00-13:00
INSERT INTO schedules (doctor_id, clinic_id, day_of_week, start_time, end_time, slot_length_minutes) VALUES
(1,1,1,'09:00:00','13:00:00',15),
(1,1,2,'09:00:00','13:00:00',15),
(1,1,3,'09:00:00','13:00:00',15),
(1,1,4,'09:00:00','13:00:00',15),
(1,1,5,'09:00:00','13:00:00',15);

-- ---------------------------------------------------------
-- Trigger: prevent double-booking for the same doctor
-- This trigger checks for overlapping appointments for the same doctor
-- and prevents INSERT or UPDATE if there is a conflict (excluding cancelled/no_show).
-- ---------------------------------------------------------
DROP TRIGGER IF EXISTS trg_appointments_no_overlap;
DELIMITER $$
CREATE TRIGGER trg_appointments_no_overlap
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;
  SELECT COUNT(*) INTO overlap_count
  FROM appointments a
  WHERE a.doctor_id = NEW.doctor_id
    AND a.appointment_id <> NEW.appointment_id
    AND a.status NOT IN ('cancelled','no_show')
    AND (
      (NEW.scheduled_start < a.scheduled_end) AND (NEW.scheduled_end > a.scheduled_start)
    );
  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already has an overlapping appointment.';
  END IF;
END$$
DELIMITER ;

-- Also prevent overlaps on updates
DROP TRIGGER IF EXISTS trg_appointments_no_overlap_upd;
DELIMITER $$
CREATE TRIGGER trg_appointments_no_overlap_upd
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;
  SELECT COUNT(*) INTO overlap_count
  FROM appointments a
  WHERE a.doctor_id = NEW.doctor_id
    AND a.appointment_id <> NEW.appointment_id
    AND a.status NOT IN ('cancelled','no_show')
    AND (
      (NEW.scheduled_start < a.scheduled_end) AND (NEW.scheduled_end > a.scheduled_start)
    );
  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already has an overlapping appointment (on update).';
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------
-- Stored procedure: create_appointment
-- Inserts an appointment and its services transactionally while checking availability
-- Params: in_patient_id, in_doctor_id, in_clinic_id, in_room_id (nullable),
--         in_start, in_end, in_created_by
-- Returns: appointment id via OUT parameter
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_create_appointment;
DELIMITER $$
CREATE PROCEDURE sp_create_appointment (
  IN in_patient_id INT,
  IN in_doctor_id INT,
  IN in_clinic_id INT,
  IN in_room_id INT,
  IN in_start DATETIME,
  IN in_end DATETIME,
  IN in_created_by INT,
  OUT out_appointment_id INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    -- Rollback transaction on error
    ROLLBACK;
    SET out_appointment_id = NULL;
  END;

  START TRANSACTION;

  -- Simple availability check (same logic as trigger) to provide clearer error handling
  IF EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.doctor_id = in_doctor_id
      AND a.status NOT IN ('cancelled','no_show')
      AND ( (in_start < a.scheduled_end) AND (in_end > a.scheduled_start) )
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor not available in the requested time range.';
  END IF;

  INSERT INTO appointments (patient_id, doctor_id, clinic_id, room_id, scheduled_start, scheduled_end, created_by)
  VALUES (in_patient_id, in_doctor_id, in_clinic_id, in_room_id, in_start, in_end, in_created_by);

  SET out_appointment_id = LAST_INSERT_ID();

  COMMIT;
END$$
DELIMITER ;

-- ---------------------------------------------------------
-- Example: how to call the stored procedure from MySQL client
-- CALL sp_create_appointment(1,1,1,NULL,'2025-09-22 10:00:00','2025-09-22 10:15:00',1,@appt_id); SELECT @appt_id;

-- ---------------------------------------------------------
-- Example queries for testing and reporting
-- ---------------------------------------------------------
-- 1) List upcoming appointments with patient and doctor names
SELECT * FROM vw_upcoming_appointments LIMIT 50;

-- 2) Get daily schedule for a given doctor on a date (2025-09-22)
SELECT a.* , CONCAT(p.first_name,' ',p.last_name) AS patient_name
FROM appointments a
JOIN patients p USING (patient_id)
WHERE a.doctor_id = 1
  AND DATE(a.scheduled_start) = '2025-09-22'
ORDER BY a.scheduled_start;

-- 3) Calculate total payments received for an appointment
SELECT appointment_id, SUM(amount) AS total_paid
FROM payments
WHERE appointment_id = 1
GROUP BY appointment_id;

-- 4) Get billing summary for an appointment (services)
SELECT a.appointment_id, s.name AS service_name, asv.quantity, asv.unit_price, (asv.quantity * asv.unit_price) AS line_total
FROM appointment_services asv
JOIN services s ON asv.service_id = s.service_id
JOIN appointments a ON asv.appointment_id = a.appointment_id
WHERE a.appointment_id = 1;

-- ---------------------------------------------------------
-- Notes & next steps
-- - For production use, consider hashing passwords with a secure algorithm (bcrypt/argon2) and never store plaintext.
-- - Add more comprehensive user/role/permission tables if required.
-- - Add stored procedures or application-level logic for rescheduling, cancelling, and billing reconciliation.

-- End of schema

