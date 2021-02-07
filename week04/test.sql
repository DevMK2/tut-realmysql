# ex1
explain extended
select e.gender, min(emp_no)
from employees e group by e.gender order by min(emp_no);
show warnings ;

# ex2
explain
select *
from employees where emp_no between 10001 and 10100 and gender='F';

# ex3
explain extended
select *
from employees where emp_no between 10001 and 10100 and gender='F';
show warnings;

# ex4
select * from employees e, salaries s
where s.emp_no=e.emp_no
  and e.emp_no between 100002 and 100020
order by e.emp_no;

# ex5
select * from employees e, salaries s
where s.emp_no=e.emp_no
  and e.emp_no between 100002 and 100010
order by e.last_name;

# ex6
select * from employees e, salaries s
where s.emp_no=e.emp_no
  and e.emp_no between 100002 and 100010
order by s.salary;
