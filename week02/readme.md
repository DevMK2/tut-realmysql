- 283p ~ 302p

### [지난 시간] 실행 계획 분석>컬럼s 
- type : 각 테이블 레코드를 '어떤 방식으로' 읽었는지를 의미한다. (mysql은 이를 join type 으로 소개한다. 하나의 테이블로부터 레코드를 읽는 것도 조인처럼 처리하기 때문)
    - ALL 만 풀 스캔, 나머지는 모두 인덱스를 사용한다.
    - 하나의 select 쿼리는 하나의 접근 방법만 사용할 수 있다. index_merge 를 제외하고는 하나의 인덱스만 사용한다.
    ```
    일반적으로 성능이 빠른 순 (레코드 건수, 데이터 분포에 따라 달라질 수는 있다.)
    system    >       const        >     eq_ref
    ref       >       fulltext     >     ref_or_null    
    unique_subquery > index_subquery  >  range
    index_merge   >   index       >      ALL
    ```
    - system : 레코드가 없거나 1건만 있는 테이블을 참조. InnoDB 테이블에서는 나타나지 않는다
    - const : p-key 나 유니크 키 컬럼을 이용하는 where 조건절 + 반드시 1 건을 반환하는 쿼리 (Unique index scan)
    - eq_ref : ***여러 테이블이 조인되는 쿼리에서만 표시된다.*** 조인에서 처음 읽은 값의 컬럼을 다음 테이블의 pkey 나 unique key 검색 조건에 사용할 때(다중 컬럼이면 모두) 그 이후 select 들에 붙는다.
    - ref : 동등 조건으로 검색될 때는 ref 방법이 사용된다. const 나 eq_ref 만큼은 아니지만 매우 빠르다.
    - const, eq_ref, ref 는 성능이 좋은 방법.
*****
### 실행 계획 분석
#### 컬럼s (계속)
- type : 각 테이블 레코드를 '어떤 방식으로' 읽었는지를 의미한다.
    - fulltext : '전문 검색 인덱스'를 통해 레코드를 읽는 접근 법. 
    성능은 레코드 건수, 데이터 분포에 따라 달라질 수 있으므로 개발자가 전문 검색 인덱스를 사용하도록 선택할 수 있다.
    전문 검색 인덱스를 사용하기 위해선 전혀 다른 쿼리를 날려야 하며 const, eq_ref, ref 의 성능이 명백히 좋은 경우가 아닌 이상 굉장히 높은 우선 순위로 전문 검색 인덱스가 사용된다.
    ('전문 검색 인덱스' 는 통계 정보가 관리되지 않는다.)
    - ref_or_null : 이름 그대로 ref 또는 null 비교. 업무에서 볼 일 별로
    - unique_subquery : where 절의 in () 형태의 쿼리를 위한 접근 방식이다. 서브 쿼리에서 유니크한 값만 반환할 때 사용한다.
    - index_subquery : in(subquery) 형태에서 subquery 가 중복된 값을 반환하지만 인덱스를 이용해 제거할 수 있음.
    - range : 인덱스 레인지 스캔 형태의 접근법이다. 주로 <, >, is null, between, in, like 등의 연산자로 인덱스를 검색할 때 범위로 검색한다. 성능이 어느정도는 보장된다고 한다.
    ```mysql
    explain
    select dept_no
    from dept_emp where dept_no between 'd001' and 'd003';
    ```
    - index_merge : 2개 이상의 인덱스를 이용하고 그 결과를 병합한다. 여러 인덱스를 읽으므로 range 보다 효율이 떨어지고, 항상 교집합이나 합집합 중복 제거 같은 부가 작업이 필요하다.
    ```mysql
    explain
    select *
    from employees
    where emp_no between 10001 and 11000
    or first_name='Smith';
    ```
    - index : 인덱스를 처음부터 끝까지 읽는 인덱스 풀 스캔을 의미한다..! 인덱스에 포함된 컬럼만으로 처리할 수 있는 쿼리인 경우이거나 인덱스를 이용하여 정렬이나 그룹핑 작업을 피할 수 있는 경우 사용된다. 
    ```mysql
    # where 절이 없어 const, ref, range 등을 사용할 수 없다.
    # 하지만 dept_name 이 인덱스가 있으므로 별도의 정렬을 피하기 위해 인덱스가 사용된 예이다. 
    explain
    select * from departments order by dept_name DESC limit 10;
    ```
    - all : 테이블 풀 스캔.
- possible_keys
    - 옵티마이저가 후보로 선정했던 인덱스의 목록일 뿐이다. 
- key
    - 실제로 실행계획에서 사용한 인덱스를 의미한다. 
    - 튜닝을 할 때 key 컬럼에 의도했던 인덱스가 표시되는지 확인하는 것이 중요하다. 
    - PRIMARY(pkey를 쓰는 경우), 인덱스 생성시 부여한 이름, NULL(인덱스를 사용하지 않는 경우) 이 나타날 수 있다.
- key_len
    - 다중 컬럼으로 구성된 인덱스에서 몇개의 컬럼까지 사용했는지 알려 준다.
    - 인덱스의 각 레코드에서 몇 바이트까지 사용했는지 알려주는 값이다. 
    - 아래 쿼리는 pkey 인 dept_no(char 4) 을 사용한다. char 에 utf-8 문자를 넣기 위해 3바이트 공간을 잡기 때문.
    ```mysql
    explain
    select * from dept_emp where dept_no='d005';
    ```
    - 아래 쿼리는 pkey 인 dept_no(char 4) 와 emp_no(int) 을 사용한다. 12 + 4 = 16 이 사용된다.
    ```mysql
    explain
    select *
    from dept_emp where dept_no='d005' and emp_no=10001;
    ```
- ref
    - 접근 방법이 ref 일 때(동등 조건으로 검색) 동등 조건으로 어떤 값이 제공됐는지 보여준다. 
    - 상수 값을 지정했다면 const로 보여지고, 다른 테이블 컬럼 값이면 테이블 명과 컬럼 명이 표시된다.
    - 참조 값을 연산을 거쳐서 참조한 경우 func 로 표시되는데 이 케이스는 조금 주의할 필요가 있다.
    ```mysql
    # de.emp_no 를 참조한다.
    explain
    select * from  employees e, dept_emp de
    where e.emp_no=de.emp_no;

    # de.emp_no 를 참조하지만 연산을 거치기 때문에 func로 표현된다.
    explain
    select * from  employees e, dept_emp de
    where e.emp_no=(de.emp_no-1);
    ```
    - 위의 케이스와 같이 명시적으로 값을 변환한 것이 아니라, MySQL 서버에 내부적으로 변환이 일어날 때에도 func 가 표시되기 때문이다. 
    (문자 집합이 일치하지 않는 두 문자열 칼럼을 조인할 때, 숫자 타입과 문자열 타입 칼럼을 조합할 때가 대표적인 예이다.)
    때문에 이러한 내부적인 변환이 일어나지 않도록 조인 컬럼의 타입을 일치시켜야하는 상황을 알아낼 수 있다.
    
- rows
    - 해당 쿼리를 처리하기 위해 얼마나 많은 레코드를 읽을 것인지 옵티마이저가 예측한 레코드 수이다.
    ```mysql
    # dept_emp.from_date 에는 모든 레코드에서 1980.01.01 이후의 값이 들어있다.
    # 때문에 옵티마이져는 테이블의 대부분의 레코드를 비교해야 한다고 판단하고 풀 테이블 스캔을 선택했다.
    explain
    select * from dept_emp where from_date>='1980-01-01';

    # dept_emp.from_date 의 범위를 줄였을 때 옵티마이져는 range 로 인덱스 스캔을 선택한다.
    explain
    select * from dept_emp where from_date>='2002-07-01';

    # 처음 쿼리에 limit 10 을 줘도 옵티마이져가 예측하는 rows 는 절반 정도(16만) 밖에 줄어들지 않는다.
    # limit 쿼리에서 옵티마이져의 예측 오차가 너무 커서 큰 의미가 없을 수 있다는 걸 보여준다.
    explain
    select * from dept_emp where from_date>='1980-01-01' limit 10;
    ```
  
- Extra
    - 중요! 고정된 몇개의 문장이 일반적으로 2~3개씩 같이 표시된다.
    - const row not found : 실행 계획에서 const 로 테이블을 읽었지만 실제로 해당 레코드가 존재하지 않는 경우.
    ```mysql
    # no matching row in const table
    explain
    select emp_no from employees where emp_no='1'
    ```
    - Distinct : 아래의 예시를 보자, dept_no 테이블에서는 조인하지 않아도 되는 항목은 무시하고 꼭 필요한 레코드만 읽었다는 것을 표현한다.
    ```mysql
    # Distinct
    explain
    select distinct d.dept_no
    from departments d, dept_emp de where de.dept_no=d.dept_no;
    ```
    - Full scan on NULL key : col1 in (select col2 from ...) 과 같은 쿼리에서 발생할 수 있다. col1 의 값이 null 이 되는 경우
    서브쿼리가 1건 이라도 결과 레코드를 가진다면 결과는 null, 서브 쿼리에 결과가 1건도 없다면 false 가 되는데,
    이러한 비교를 위해서는 풀 테이블 스캔을 해야만 한다는 것을 나타낸다.
        - in 절 왼쪽의 컬럼이 Nullable 이면 실제로 null 인 값이 없더라도 해당 코멘트가 표시될 수 있다.
    ```mysql
    explain 
    select d.dept_no, NULL in (select id.dept_name from departments id)
    from departments d;
    ```
    - Impossible HAVING : having 절의 조건을 만족시키는 레코드가 없는 경우. 쿼리가 잘못 작성된 경우가 많다.
    - Impossible WHERE : 위와 비슷하게 where 조건이 항상 false 가 될 수 밖에 없는 경우를 나타낸다.
    - Impossible WHERE noticed after reading const tables : 아래와 같은 경우를 생각해보자. emp_no 가 0이 되는 경우가 있는지 없는지는 실제로 쿼리를 실행해봐야 알 수 있다. 그러나 아래 쿼리는 const 방식으로 접근하고 이 경우 옵티마이저가 쿼리 일부를 실행한 뒤 그 값을 상수로 대체한다는 것을 알 수 있다.
    ```mysql
    explain 
    select * from employees where emp_no=0;
    ```
