- 263p ~ 283p 

### 쿼리 실행 절차
1. SQL 문장을 파싱
2. 파스트리를 확인하면서 '어떤 테이블 부터' 읽고, '어떤 인덱스를 이용해' 테이블을 읽을지 결정한다.
    - 불필요한 조건 제거 및 복잡한 연산 단순화
    - 조인이 있는 경우 어떤 순서로 테이블을 읽을지 결정
    - 각 테이블에 사용된 '조건' 과 '인덱스 통계 정보' 를 통해 사용할 인덱스 결정
    - 가져온 레코드들을 임시 테이블에 넣고 다시 가공해야 하는지 결정    
3. 실행 계획대로 데이터를 가져온다.

### 옵티마이저 종류, 비용 기반 최적화 VS 규칙 기반 최적화
- 비용 기반 최적화는 여러가지 실행 방법을 만들고, 각 단위 작업 비용과 대상 테이블의 '예측 통계 정보'를 통해 실행 계획별 비용을 산출한다.
규칙 기반 최적화는 이런 것들을 고려하지 않고 내장된 우선순위에 다라 실행 계획을 수립하며 현재 사용되지 않는다.

### 통계정보
- 예를 들어 1억 건의 레코드가 있는 테이블의 통계 정보가 갱신되지 않아서 레코드가 10건 미만인 것 처럼 되어있다면 옵티마이저는 풀스캔을 실행해버릴수도 있다.
- MySQL 에서 사용되는 통계정보는 다른 DBMS 에 비해 단순한 편이다.
    - 레코드 건수
    - 인덱스의 유니크 벨류 개수
- 위의 이유로 인해 MySQL 의 통계 정보는 상당히 동적으로 변경되는 편이며, 레코드 건수가 적으면(개발용 스토리지인 경우) 통계 정보가 부정확해 ANALYZE 명령으로 통계 정보를 갱신해야 할 때도 있다.
- MyISAM 과 InnoDB 의 테이블, 인덱스 통계 정보는 다음과 같이 확인한다.
```mysql
# ex1
show table status like 'employees';
show index from employees;
```
- 통계 정보를 갱신하려면 다음과 같이 한다.
```mysql
# ex2
## 파티션을 사용하지 않는 일반 테이블의 통계 정보 수집
analyze table tb_dual;
## 파티션을 사용할 때 특정 파티션의 통계 정보 수집
alter table tb_dual analyze partition p3;
```
- analyze 를 하는 동안 MyISAM 테이블은 읽기 가능 쓰기 불가능이며, InnoDB 테이블은 읽기,쓰기 불가능이다 그러므로 서비스 중에는 실행하지 않는 것이 좋다.
- MyISAM 의 Analyze 는 모든 인덱스를 스캔하므로 시간이 많이 소요된다.
- InnoDB 의 Analyze 는 페이지 중 8개만 랜덤으로 선택, 분석하고 그 결과를 통계 정보로 갱신한다. 5.1.38 이상의 InnoDB 플러그인 버전에서는 "innodb_stats_sample_pages" 파라미터로 이 수를 지정할 수 있다.

### 실행 계획 분석
- 실행 계획은 explain, explain extended, explain partitions 명령으로 확인할 수 있다.
```mysql
# ex3
explain 
select e.emp_no, e.first_name, s.from_date, s.salary
from employees e, salaries s
where e.emp_no=s.emp_no
limit 10;
```
- 레코드는 쿼리에 사용된 테이블(서브 쿼리에 생성되는 임시 테이블 포함) 개수 만큼 출력된다.
- 실행 순서는 위에서 아래로 순서대로 표시된다. (union 이나 상관 서브쿼리는 아닐 수도 있다.)
- 위쪽일 수록(id 컬럼 값이 작을수록) 쿼리의 바깥 부분이거나, 먼저 접근한 테이블이다.
- update, insert, delete 는 실행 계획을 확인할 방법이 없다. (where 절만 같은 select 를 통해 대략적으로 확인하는 방법이 있다.)

#### 컬럼s
- id : 단위 select 쿼리별로 부여되는 식별자. 같은 id인 경우 조인되는 쿼리이다.
- select_type : 
    - SIMPLE : union 이나 서브 쿼리를 사용하지 않는 단순한 select 쿼리인 경우 + join 이 포함된 경우. simple 쿼리는 반드시 하나만 존재해야 하며 일반적으로 제일 바깥 쿼리가 simple 로 표시된다. 
    - PRIMARY : union 이나 서브 쿼리가 포함된 실행 계획에서 가장 바깥쪽에 있는 쿼리는 primary 로 표시된다.
        ```mysql
        # ex4
        explain 
        select((select count(*) from employees e) + (select count(*) from departments d)) as total_count;
        ```
    - UNION : union 으로 결합하는 쿼리 가운데 첫 번째를 제외한 이후 쿼리는 UNION 으로 표시된다. union의 첫 번째 select 는 union 으로 결합된 전체 집합의 타입이 표시된다.
        ```mysql
        # ex5 - union 된 전체 결과를 임시 테이블로 사용하므로 union all 의 첫 번째 쿼리는 derived 라는 타입을 갖는다 
        explain 
        select * from (
          (select emp_no from employees e1 limit 10)                     
          union all
          (select emp_no from employees e2 limit 10)
          union all
          (select emp_no from employees e3 limit 10)
        ) tb;
        ```
    - DEPENDENT UNION : UNION 과 마찬가지이다. DEPENDENT 의 의미는 union 이나 union all 로 결합 된 쿼리가 외부 영향에 의해 영향을 받는 것을 의미한다.
    - DEPENDENT SUBQUERY : 서브 쿼리가 바깥쪽에서 정의된 칼럼을 사용하는 경우.
        ```mysql
        # ex6
        explain
        select e.first_name,
        (
            select concat('Salary change count : ', count(*)) as message from salaries s where s.emp_no = e.emp_no
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
        ``` 
    - DERIVED : 단위 select 쿼리 결과를 메모리나 디스크에 임시 테이블로 생성하는 것을 의미한다. 
    파생 테이블에는 인덱스가 전혀 없으므로 다른 테이블과 조인할 때 ***성능상 불리***할 때가 많다. 
    ***서브 쿼리가 FROM 절에 사용된 경우*** mysql 은 항상 derived 인 실행 계획을 만든다.
    서브 쿼리가 derived 인 경우 join 으로 풀어서 성능 개선을 해야 하는 이유이다.

    ``` 
    - SUBQUERY 는 바깥의 영향을 받지 않으므로 결과를 캐시한다.
    - DEPENDENT SUBQEURY 는 의존하는 바깥 쿼리의 컬럼 값 단위로 캐시한다.
    ```
    - UNCHANGABLE SUBQUERY : 서브쿼리에 포함된 요소 때문에 쿼리를 못하는 경우.
        - 사용자 변수가 서브 쿼리에 사용된 경우
        - not-deterministic 속성의 스토어드 루틴이 사용된 경우
        - UUID 나 RAND 같이 결과값이 호출할 때마다 달라지는 함수가 서브 쿼리에 적용된 경우
        ```mysql
        explain
        select *
        from employees e
        where e.emp_no = (
        select @status from dept_emp de where de.dept_no='d005'
        );
        ```
    - UNCHANGABLE UNION : union 으로 결합하는 쿼리 중 사용자 변수, not-deterministic 스토어드 루틴, non-deterministic 함수가 포함된 경우
- table : 접근하는 테이블, 별칭으로 나타나며 <%s%d,type,id>로 둘러싸인 것은 임시 테이블을 의미한다. 숫자는 파생 테이블이 만들어진 쿼리의 id를 나타낸다
- type : 각 테이블 레코드를 '어떤 방식으로' 읽었는지를 의미한다. (mysql은 이를 join type 으로 소개한다. 하나의 테이블로부터 레코드를 읽는 것도 조인처럼 처리하기 때문)
    - ALL 만 풀 스캔, 나머지는 모두 인덱스를 사용한다.
    - 하나의 select 쿼리는 하나의 접근 방법만 사용할 수 있다. index_merge 를 제외하고는 하나의 인덱스만 사용한다.
    ```
    성능이 빠른 순
    system    >       const        >     eq_ref
    ref       >       fulltext     >     ref_or_null    
    unique_subquery > index_subquery  >  range
    index_merge   >   index       >      ALL
    ```

    - system : 레코드가 없거나 1건만 있는 테이블을 참조. InnoDB 테이블에서는 나타나지 않는다
    ```mysql
    # ex11
    explain 
    select * from tb_dual
    ```
    - const : p-key 나 유니크 키 컬럼을 이용하는 where 조건절 + 반드시 1 건을 반환하는 쿼리 (Unique index scan)
    ```mysql
    # ex12
    explain 
    select * from employees where emp_no=10001;
    show tables ;
    select * from employees;
    ```
    - eq_ref : ***여러 테이블이 조인되는 쿼리에서만 표시된다.*** 조인에서 처음 읽은 값의 컬럼을 다음 테이블의 pkey 나 unique key 검색 조건에 사용할 때(다중 컬럼이면 모두) 그 이후 select 들에 붙는다.
    ```mysql
    # ex13
    explain
    select * from dept_emp de, employees e
    where e.emp_no=de.emp_no and de.dept_no='de005';
    ```
    - ref : 동등 조건으로 검색될 때는 ref 방법이 사용된다. const 나 eq_ref 만큼은 아니지만 매우 빠르다.
    ```mysql
    explain 
    select * from dept_emp de where de.dept_no='de005';
    ``` 