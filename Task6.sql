create database School;
use School;

-- Students, Subjects, Exams, Scores, Attendance
CREATE TABLE students (
student_id INT AUTO_INCREMENT PRIMARY KEY,
first_name VARCHAR(100),
last_name VARCHAR(100),
class VARCHAR(50),
section VARCHAR(10),
dob DATE,
gender ENUM('M','F','O'),
enrollment_date DATE
);


CREATE TABLE subjects (
subject_id INT AUTO_INCREMENT PRIMARY KEY,
subject_name VARCHAR(100)
);


CREATE TABLE exams (
exam_id INT AUTO_INCREMENT PRIMARY KEY,
exam_name VARCHAR(100),
exam_date DATE
);


CREATE TABLE scores (
score_id INT AUTO_INCREMENT PRIMARY KEY,
student_id INT,
subject_id INT,
exam_id INT,
marks DECIMAL(5,2),
max_marks DECIMAL(5,2),
graded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (student_id) REFERENCES students(student_id),
FOREIGN KEY (subject_id) REFERENCES subjects(subject_id),
FOREIGN KEY (exam_id) REFERENCES exams(exam_id)
);


CREATE TABLE attendance (
attendance_id INT AUTO_INCREMENT PRIMARY KEY,
student_id INT,
attendance_date DATE,
status ENUM('present','absent','late','excused'),
FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- Add indexes for performance

CREATE INDEX idx_scores_student ON scores(student_id);
CREATE INDEX idx_scores_exam ON scores(exam_id);
CREATE INDEX idx_attendance_date ON attendance(attendance_date);

-- Inserting names of students
INSERT INTO students(first_name,last_name,class,section,dob,enrollment_date,gender)
VALUES
('Aisha','Khan','10','A','2009-04-15','2022-06-01','F'),
('Rahul','Sharma','10','A','2009-07-02','2022-06-01','M'),
('Sana','Aafreen','10','B','2009-12-20','2022-06-01','F');


INSERT INTO subjects(subject_name) VALUES ('Math'), ('Science'), ('English');


INSERT INTO exams(exam_name, exam_date) VALUES ('Midterm','2025-08-15'),('Final','2025-12-10');


INSERT INTO scores(student_id,subject_id,exam_id,marks,max_marks)
VALUES
(1,1,1,78,100), (1,2,1,85,100), (1,3,1,72,100),
(2,1,1,55,100), (2,2,1,48,100), (2,3,1,60,100),
(3,1,1,90,100),(3,2,1,92,100),(3,3,1,88,100);


INSERT INTO attendance(student_id,attendance_date,status)
VALUES
(1,'2025-08-10','present'),(1,'2025-08-11','present'),
(2,'2025-08-10','absent'),(2,'2025-08-11','present'),
(3,'2025-08-10','present'),(3,'2025-08-11','late');

-- Viewing Data
-- Student overall percentage per exam
CREATE VIEW vw_student_exam_percentage AS
SELECT
s.student_id,
s.first_name,
s.last_name,
e.exam_id,
e.exam_name,
SUM(sc.marks) AS total_marks_obtained,
SUM(sc.max_marks) AS total_max_marks,
ROUND( (SUM(sc.marks)/SUM(sc.max_marks))*100, 2) AS percentage
FROM scores sc
JOIN students s ON s.student_id = sc.student_id
JOIN exams e ON e.exam_id = sc.exam_id
GROUP BY sc.student_id, sc.exam_id;


-- Subject averages per exam
CREATE VIEW vw_subject_avg AS
SELECT
exam_id,
subject_id,
AVG(marks) AS avg_marks,
AVG(marks)/AVG(max_marks)*100 AS avg_pct
FROM scores
GROUP BY exam_id, subject_id;


-- Student attendance summary
CREATE VIEW vw_attendance_summary AS
SELECT
a.student_id,
COUNT(*) AS total_days_marked,
SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) AS present_days,
SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) AS absent_days,
ROUND( SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS attendance_pct
FROM attendance a
GROUP BY a.student_id;

-- Overall class average(per exam)
SELECT
e.exam_name,
ROUND(AVG(vw.percentage),2) AS class_avg_percentage
FROM vw_student_exam_percentage vw
JOIN exams e ON e.exam_id = vw.exam_id
GROUP BY vw.exam_id;

-- Top 5 students by percentage
SELECT student_id, first_name, last_name, percentage
FROM vw_student_exam_percentage
WHERE exam_id = 1
ORDER BY percentage DESC
LIMIT 5;

-- Pass / Fail count (simple rule: pass if percentage >= 40)
SELECT
SUM(CASE WHEN percentage >= 40 THEN 1 ELSE 0 END) AS passed_count,
SUM(CASE WHEN percentage < 40 THEN 1 ELSE 0 END) AS failed_count
FROM vw_student_exam_percentage
WHERE exam_id = 1;
-- Subject-wise average and rank
SELECT
sub.subject_name,
sa.avg_marks,
ROUND(sa.avg_pct,2) as avg_pct
FROM vw_subject_avg sa
JOIN subjects sub ON sub.subject_id = sa.subject_id
WHERE sa.exam_id = 1
ORDER BY sa.avg_marks DESC;

-- Attendance rates (class-level, date range)

SELECT
COUNT(DISTINCT student_id) AS students_count,
SUM(CASE WHEN status='present' THEN 1 ELSE 0 END) AS present_count,
ROUND( SUM(CASE WHEN status='present' THEN 1 ELSE 0 END) / COUNT(*) * 100,2) AS overall_attendance_pct
FROM attendance
WHERE attendance_date BETWEEN '2025-08-01' AND '2025-08-31';

-- At-risk students — low attendance OR low marks
SELECT
s.student_id, s.first_name, s.last_name,
COALESCE(a.attendance_pct,0) AS attendance_pct,
COALESCE(v.percentage,0) AS last_exam_pct
FROM students s
LEFT JOIN vw_attendance_summary a ON a.student_id = s.student_id
LEFT JOIN (
SELECT student_id, percentage FROM vw_student_exam_percentage WHERE exam_id = 1
) v ON v.student_id = s.student_id
WHERE COALESCE(a.attendance_pct,0) < 75 OR COALESCE(v.percentage,0) < 40;