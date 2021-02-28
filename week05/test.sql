# using index for group-by
explain
select emp_no from salaries where from_date='1985-03-01' group by emp_no;

# using  temporary table
explain
select e.last_name, e.first_name, AVG(s.salary) from employees e, salaries s
where s.emp_no = e.emp_no
group by e.last_name, e.first_name;

explain
select e.last_name, e.first_name, AVG(s.salary) from employees e, salaries s
where s.emp_no = e.emp_no
group by e.emp_no;

# group by 와 같이 처리되나 정렬이 보장되지 않을 뿐이다.
explain
select distinct emp_no from salaries;

explain
select count(distinct s.salary), count(distinct e.last_name)
from employees e, salaries s
where e.emp_no=s.emp_no
and e.emp_no between 100001 and 100100;

explain
select count(distinct e.emp_no)
from employees e, salaries s
where e.emp_no=s.emp_no
  and e.emp_no between 100001 and 100100;

show session status like 'Created_tmp%';
select first_name,last_name from employees group by first_name, last_name;
