- 342p ~ 358p

### MySQL 의 주요 처리 방식.
- 풀 테이블 스캔만 스토리지 엔진에서 처리되는 내용이며 나머지 내용은 MySQL 엔진에서 처리되는 내용이다. 

#### 풀 테이블 스캔 
- 주로 다음 조건일 때 선택된다.
```
- 레코드 건수가 너무 작아서 인덱스를 사용하는 것보다 빠른경우
- where나 on절에 인덱스를 이용할 조건이 없는 경우
- 인덱스 레인지 스캔을 쓸 수 있는 쿼리라도 옵티마이저가 판단하기에 조건 일치 레코드 건수가 너무 많은 경우
- max_seeks_for_key 를 특정 값 N 으로 설정하면 MySQL 옵티마이저는 인덱스 기수성/선택도 등을 무시하고 최대 N건만 읽으면 된다고 판단하게 된다.
  그러므로 이 값을 적게 설정할 수록 서버가 인덱스를 사용하도록 유도하는 효과가 있다.
```

#### ORDER BY 처리 
- Filesort 방식과 인덱스를 이용한 정렬 방식
    - 소트 버퍼 : 정렬을 수행하기 위해 따로 할당한 메모리 공간이다. 최대 사용 공간은 sort_buffer_size로 설정할 수 있으며 최적 크기는 trial 로 찾아봐야 한다.
            정렬할 데이터가 많지 않아 메모리에만 소트 버퍼가 잡히면 문제 없지만 데이터가 많아서 디스크를 써야하는 경우 정렬, 합성에 많은 리소스가 필요하게된다.
    - 정렬 알고리즘 : 소트 버퍼에 모든 컬럼을 전부 담아 정렬하는 싱글 패스 알고리즘과, 정렬 대상 컬럼과 pkey만 소트 버퍼에 담아 정렬하고 정렬된 순서대로 다시 다른 컬럼을 채우는 투 패스 알고리즘이 있다.
            레코드 건수가 작은 경우 싱글 패스가 빠르나, 레코드 크기가 max_length_for_sort_data 를 넘어서거나 BLOB이나 TEXT타입 컬럼이 select 대상에 포함될 때 싱글패스를 사용하지 못하고 투패스가 사용된다. 
    - 정렬의 처리 방식 : 인덱스 사용한 정렬 > 드라이빙 테이블만 정렬 후 조인 > 조인결과를 임시테이블로 저장한 후 임시테이블에서 정렬.
    
- 스트리밍 방식과 버퍼링 방식
    - order by 와 limit 는 필수적으로 사용되는 경향이 많다.
      일반적으로 limit 은 테이블이나 처리 결과의 일부만 가져오기 때문에 MySQL 엔진의 작업량을 줄이는 역할을 한다.
      그러나 order by, group by 는 우선 정렬이나 그룹핑을 한 후에야 limit 을 적용할 수 있다.
    - 스트리밍 방식 : 조건에 일치하는 레코드가 검색될 떄마다 바로 클라이언트로 전송해주는 방식.
    - 버퍼링 방식 : order by, group by 는 스트리밍 방식으로 쿼리가 처리되는 것을 불가능하게 한다.
            인덱스를 사용한 정렬의 경우에만 스트리밍 형태로 처리되며 나머지는 모두 버퍼링된 후 정렬된다.

#### GROUP BY 처리
- group by 또한 스트리밍 방식으로 처리할 수 없게 하는 요소 중 하나다. 
  group by 도 인덱스를 사용하는 경우와 그렇지 않은 경우로 나뉘는데,
  인덱스를 사용하는 경우는 인덱스를 차례대로 이용하는 인덱스 스캔과 인덱스를 건너뛰면서 읽는 루스 인덱스 스캔으로 나누며
  인덱스를 사용하지 못하는 쿼리에서는 임시테이블을 사용한다.
  
- 인데스 스캔을 사용하는 GROUP BY
    - 조인의 드라이빙 테이블에 속한 칼럼만 이용해서 그루핑할 때 GROUP BY 칼럼으로 인덱스가 있다면, 인덱스를 차례로 읽으면서 조인을 처리한다.
    - 인덱스를 사용하므로 정렬은 따로 필요하지 않으며 다음과 같은 코멘트가 ***남지 않는다***.
    (Using inde for group-by, Using temporary, Using filesort)
    
- 루스 인덱스 스캔을 사용하는 GROUP BY
    - 인덱스의 레코드를 건너뛰면서 필요한 부분만 가져오는 것을 의미한다.
    
    ```mysql
    explain
    select emp_no from salaries 
    where from_date='1985-03-01'
    group by emp_no;
    ```
    - salaries 테이블은 (emp_no, from_date) 로 인덱싱 되어 있다. 때문에 위의 쿼리의 where 문은 index range scan을 할 수 없는 쿼리이지만
      실행계획은 range 를 이용했으며 group by 처리까지 인덱스를 사용했다는 것을 보여준다.
        1. 인덱스를 차례로 스캔하면서 emp_no의 첫번째 그룹 키를 찾는다.
        2. emp_no 이 그룹 키 인것 중에서 from_date 값이 where 조건에 맞는 것을 찾는다. 이는 emp_no + from_date 로 찾는 것과 흡사하다.
        
- 임시 테이블을 사용하는 GROUP BY
    - GROUP BY 의 기준 컬럼이 인덱스를 전혀 사용하지 못하는 경우.
    - 아래 쿼리는 using temporary; using fiilesort 를 표시한다. 이는 테이블을 풀 스캔하기 떄문이 아니라 인덱스를 사용할 수 없는 group by 이기 때문이다.
    ```mysql
    # using temporary table
    explain
    select e.last_name, e.first_name, AVG(s.salary) from employees e, salaries s
    where s.emp_no = e.emp_no
    group by e.last_name, e.first_name;
  
    # group by index
    explain
    select e.last_name, e.first_name, AVG(s.salary) from employees e, salaries s
    where s.emp_no = e.emp_no
    group by e.emp_no;
    ```
  
#### DISTINCT 처리
- 유일 값을 select 한다는 점에서 group by 와 유사하게 사용될 수 있으나 정렬이 보장되지 않을 뿐이다.
- 컬럼의 조합을 유일하게 선택하는 것이지 특정 컬럼만 유니크하게 사용할 수는 없다(distinct(colmun)과 같은 쿼리에서는 괄호가 무시 될 뿐이다).
  단 count 와 같은 집합 함수 내부에서 사용하는 경우 컬럼이 유니크하도록 조회하게 되는데 이때도 인덱스를 사용하는 것이 성능 이점을 가져올 수 있다.
  
 #### 임시 테이블 
 - 임시 테이블이 필요한 쿼리들은 아래와 같다.
   실행 계획에서 select_type 에 using temporary 가 표시되므로 알 수 있다(마지막 세 케이스 제외).
    1. order by 나 group by 에 명시된 컬럼이 다른 쿼리
    1. order by 나 group by 에 명시된 컬럼이 조인 순서상 첫번째 테이블이 아닌 쿼리
    3. distinct 와 order by 가 동시에 존재하는 경우 + distinct 가 인덱스로 처리되지 못하는 쿼리
    4. union, union distinct 가 사용된 쿼리 (select_type = union result)
    5. union all 이 사용된 쿼리 (select_type = union result)
    6. 실행 계획에서 select_type 이 derived 인 쿼리
    
- 임시 테이블이 디스크에 만들어졌는지 메모리에 만들어졌는지는 아래와 같이 파악할 수 있다.
```mysql
show session status like 'Created_tmp%';
select first_name,last_name from employees group by first_name, last_name;
show session status like 'Created_tmp%';
```

- 디스크에 임시 테이블이 저장된 경우라면 레코드 건수가 많다는 것이므로 적지 않은 부하가 발생한다.
  임시 테이블이 필요하지 않게 만드는 것이 가장 좋지만 어렵다면 임시 테이블이 메모리에 저장되도록 레코드를 적게 만드는 것이 좋다.
  
- 임시 테이블이 메모리에 생성되는 경우에도 주의 할 점이 있는데, 테이블의 모든 컬럼을 고정 크기로 잡는 다는 것이다.
  때문에 컬럼의 데이터 타입 선정을 적게 해주고 select 하는 컬럼은 최소화하는 것이 좋다(특히 blob 이나 text 컬럼은 필요하지 않으면 반드시 빼자).
