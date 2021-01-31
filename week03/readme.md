- 302p ~ 321p

### 실행 계획 분석
#### 컬럼s (계속)
- Extra
    - 고정된 몇개의 문장이 일반적으로 2~3개씩 같이 표시되면서 실행계획이나 결과에 대한 경고 등을 보여준다.

    - No matching min/max row : where 절을 만족하는 레코드가 없고, min/max 함수가 있는 경우.
    ```mysql
    explain
    select min(dept_no), max(dept_no)
    from dept_emp where dept_no='';
    ```
  
    - no matching row in const table : 조인에 사용된 테이블에서 일치하느 레코드가 없음을 의미함.
    ```mysql
    explain
    select *
    from dept_emp de,
         (select emp_no from employees where emp_no=0) tb1
    where tb1.emp_no=de.emp_no and de.dept_no='d005';
    ```
  
    - No tables used : from 절 자체가 없거나, from 절에 가상 테이블이 존재하는 경우
    ```mysql
    explain select 1;
    explain select 1 from dual; 
    # 가상 상수 테이블
    ```

    - Not exists : A 테이블에는 존재하지만 B 테이블에는 없는 값을 조회해야하는 쿼리가 자주 사용된다. 
    이때 주로 not in / not exists 을 쓰지만 레코드 건수가 많을 때는 아래와 같이 아우터 조인을 하면 성능 이득을 볼 수 있다.
    이렇게 아우터 쿼리를 이용해서 안티-조인을 수행라 때 Not exists 메시지가 표시된다.
    이 메시지는 내부적으로 최적화한 이름이 Not exists 라는 뜻이다.
    ```mysql
    explain
    select *
    from dept_emp de left join departments d 
      on de.dept_no = d.dept_no
    where d.dept_no is null;
    ```
  
    - Range checked for each record (index map: N) : e2 테이블의 N 번째 인덱스를 사용할지, 아니면 풀 스캔을 할 지 매번 판단하면서
    e1 의 매 레코드마다 인덱스 레인지 스캔을 체크한다는 의미이다. 이 때 e1 의 레코드가 인덱스를 사용하는게 도움이 되지 않는 경우에는 풀 스캔을 하기 때문에 type에는 ALL 이 뜬다.
    ```mysql
    explain
    select *
    from employees e1, employees e2
    where e2.emp_no >= e1.emp_no
    ```
  
    - using filesort : order by 가 적절한 인덱스를 못 찾아서 사용 못할 때 표시된다. (정렬용 메모리 버퍼에 복사 후 퀵소트로 정렬한다)
    
    - using index : 파일을 전혀 읽지 않고 인덱스만으로 쿼리를 처리할 수 있을 때 표시된다. 
    ```mysql
    # using where : ix_firstname 인덱스로 검색은 가능하지만 birth_date를 위해 디스크를 더 읽어야 한다.
    explain
    select first_name, birth_date
    from employees where first_name between 'Babette' and 'Gad';

    explain
    select first_name
    from employees where first_name between 'Babette' and 'Gad';
  
    # emp_no 는 pkey 이므로 이미 인덱스에 포함되어 있어 파일을 읽지 않아도 된다.
    explain
    select emp_no, first_name
    from employees where first_name between 'Babette' and 'Gad';
    ```
    
    - using index for group-by: group by 가 인덱스를 통해 처리될 때 표시된다.
    group by 처리는 정렬을 수행하고 다시 그루핑하는 형태로 이루어지는데, 이때 인덱스를 사용하면 정렬이 필요하지 않으므로 효율적으로 처리된다. group by 는 루스 인덱스 스캔 방식으로 처리된다.
    
    - using join buffer : 보통 성능을 위해 조인이 되는 컬럼은 인덱스를 생성한다. 조인에 필요한 인덱스는 조인에서 뒤에 읽는 테이블의 컬럼에만 필요하다. 
    드리븐 테이블에 인덱스가 없다면 드라이빙 테이블의 레코드 건수만큼 매번 드리븐 테이블을 풀스캔해야 할 것이다.
    이때 드라이빙 테이블에서 읽은 레코드를 캐싱하는데 이를 조인 버퍼라고하며 'using join buffer' 가 표시된다.
    
    - using sort_union, using union, using intersect : 쿼리가 index_merge 타입으로 실행된 경우, 두 인덱스로부터 읽은 결과를 어떻게 병합했는지 설명한다.
    ```
    1. using intersect : 각 처리 결과에서 교집합을 추출했음.
    2. using union : 각 처리 결과에서 합집합을 추출했음.
    2. using sort_union : using union과 같은 작업을 수행하지만,
                          where 절에 동등조건이 아니라서 다량의 range 조건이 걸린 경우 
                          pkey 만 읽어서 정렬 후 병합한 후에야 레코드를 읽어서 반환한다.
    ```
