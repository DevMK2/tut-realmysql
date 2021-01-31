# ex1
explain
select min(dept_no), max(dept_no)
from dept_emp where dept_no='';

# ex2
explain
select *
from dept_emp de,
     (select emp_no from employees where emp_no=0) tb1
where tb1.emp_no=de.emp_no and de.dept_no='d005';

# ex3
explain select 1;

# ex4
explain
select *
from dept_emp de left join departments d on de.dept_no = d.dept_no
where d.dept_no is null;

# ex5
explain
select *
from employees e1, employees e2
where e2.emp_no >= e1.emp_no;

# ex6
explain
select table_name
from information_schema.TABLES
where TABLE_SCHEMA='employees' and TABLE_NAME='employees';

# ex7
explain
select first_name, birth_date
from employees where first_name between 'Babette' and 'Gad';

explain
select first_name
from employees where first_name between 'Babette' and 'Gad';

explain
select emp_no, first_name
from employees where first_name between 'Babette' and 'Gad';

# ex8
explain
select first_name, count(*) as counter
from employees
group by first_name;

explain
select emp_no, min(from_date), max(from_date)
from salaries
group by emp_no;
