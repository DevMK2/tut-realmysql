# ex1
explain
select * from employee_name
where emp_no=10001
  and emp_no between 10001 and 10005
  and match(first_name, last_name) against('Facello' in BOOLEAN MODE);

# ex2
explain
select *
from titles
where to_date='1985-03-01' or to_date is null;

# ex3
explain
select * from departments where dept_no in (
    select dept_no from dept_emp where emp_no=10001
);

# ex4
explain
select *
from departments where dept_no in(
    select dept_no
    from dept_emp where dept_emp.dept_no between 'd001' and 'd003'
);

# ex5
explain
select dept_no
from dept_emp where dept_no between 'd001' and 'd003';

# ex6 index_merge
explain
select *
from employees
where emp_no between 10001 and 11000
or first_name='Smith';

# ex7
explain
select * from departments order by dept_name DESC limit 10;

# ex8
explain
select * from dept_emp where dept_no='d005';

# ex9
explain
select *
from dept_emp where dept_no='d005' and emp_no=10001;

# ex10
explain
select * from  employees e, dept_emp de
where e.emp_no=de.emp_no;

# ex11
explain
select * from  employees e, dept_emp de
where e.emp_no=(de.emp_no-1);

# ex12
explain
select * from dept_emp where from_date>='1980-01-01';

# ex13
explain
select * from dept_emp where from_date>='2002-07-01';

# ex14
explain
select * from dept_emp where from_date>='1980-01-01' limit 10;

# no matching row in const table
explain
select emp_no from employees where emp_no='1';

# Distinct
explain
select distinct d.dept_no
from departments d, dept_emp de where de.dept_no=d.dept_no;

# Full scan on NULL key
explain
select d.dept_no, NULL in (select id.dept_name from departments id)
from departments d;
