show tables;

# ex1
show table status like 'tb_dual';
show index from tb_dual;

# ex2
## 파티션을 사용하지 않는 일반 테이블의 통계 정보 수집
analyze table tb_dual;
## 파티션을 사용할 때 특정 파티션의 통계 정보 수집
alter table tb_dual analyze partition p3;

# ex3
explain
select e.emp_no, e.first_name, s.from_date, s.salary
from employees e, salaries s
where e.emp_no=s.emp_no
limit 10;

# ex4
explain
select((select count(*) from employees) + (select count(*) from departments)) as total_count;

# ex5 - union 된 전체 결과를 임시 테이블로 사용하므로 union all 의 첫 번째 쿼리는 derived 라는 타입을 갖는다
explain
select * from (
    (select emp_no from employees e1 limit 10)
    union all
    (select emp_no from employees e2 limit 10)
    union all
    (select emp_no from employees e3 limit 10)
) tb;

# ex6
explain
select e.first_name,
(
    select  concat('Salary change count : ', count(*)) as message from salaries s where s.emp_no = e.emp_no
    union
    select concat('Departed change count : ', count(*)) as message from dept_emp de where de.emp_no = e.emp_no
) as message
from employees e
where e.emp_no=10001;

# ex7
explain
select e.first_name,
(
    select count(*)
    from dept_emp de, dept_manager dm
    where dm.dept_no=de.dept_no and de.emp_no=e.emp_no
) as cnt
from employees e
where e.emp_no=10001;

# ex8
explain
select *
from (
    select * from dept_emp de
) tb, employees e
where e.emp_no = tb.emp_no;

# ex9
explain
select *
from employees e
where e.emp_no = (
select @status from dept_emp de where de.dept_no='d005'
);

# ex10
explain
select *
from (select * from dept_emp) te, employees e
where e.emp_no=te.emp_no;

# ex11, InnoDB 이기 때문에 system 이 아닌 index 로 나온다
explain
select * from tb_dual;

# ex12
# pkey 로 where 절이 걸린 경우 1 건만 리턴하게 되므로 const type 이 된다.
explain
select * from employees where emp_no=10001;
# 다중 컬럼으로 pkey 가 구성된 경우 그 일부만 걸려있을 때는 ref 가 된다.
explain
select *
from dept_emp where dept_no='d005';
# 다중 컬럼 pkey 전체를 걸어주면 const
explain
select *
from dept_emp where dept_no='d005' And emp_no=10001;

# ex13
explain
select * from dept_emp de, employees e
where e.emp_no=de.emp_no and de.dept_no='de005';
